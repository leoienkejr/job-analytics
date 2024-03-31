'''
Scrape and load job listings into the data lake
'''

import re
import time
import json
import base64
import logging
import argparse
import random
from io import BytesIO
from hashlib import md5
from typing import Union
from itertools import chain
from functools import partial
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
import boto3
import requests
import pandas as pd
from loguru import logger
from dotenv import dotenv_values
from bs4 import BeautifulSoup
from aiolimiter import AsyncLimiter
from selenium import webdriver
from selenium.common.exceptions import WebDriverException, NoSuchElementException
from selenium.webdriver.common.by import By

CONFIG=dotenv_values()

RESULTS_COUNT_ELEMENT_CLASS = 'results-context-header__job-count'
LISTING_LINK_ELEMENT_CLASS = 'base-card__full-link'
LISTING_TITLE_ELEMENT_CLASS = 'top-card-layout__title'
LISTING_LOCATION_ELEMENT_CLASS = 'topcard__flavor--bullet'
LISTING_COMPANY_ELEMENT_CLASS = 'topcard__org-name-link'
LISTING_DESCRIPTION_ELEMENT_CLASS = 'show-more-less-html__markup'
LISTING_CRITERIA_SENIORITY_ELEMENT_XPATH = '''//h3[contains(text(),'Seniority level')]/parent::li/span'''
LISTING_CRITERIA_JOB_FUNCTION_ELEMENT_XPATH = '''//h3[contains(text(),'Job function')]/parent::li/span'''
LISTING_CRITERIA_INDUSTRIES_ELEMENT_XPATH = '''//h3[contains(text(),'Industries')]/parent::li/span'''
LISTING_CRITERIA_EMPLOYMENT_TYPE_ELEMENT_XPATH = '''//h3[contains(text(),'Employment type')]/parent::li/span'''
LISTING_SHOW_MORE_BTN_CLASS = '.show-more-less-html__button.show-more-less-html__button--more'
LISTING_CRITERIA_ELEMENT_CLASS = 'description__job-criteria-subheader'

HTTP_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:108.0) Gecko/20100101 Firefox/108.0'
}


@dataclass
class Listing:
    '''
    LinkedIn listing
    '''

    title: str
    location: str
    url: str
    company_name: str
    company_url: str
    description: str
    seniority: Union[str, None] = None
    employment_type: Union[str, None] = None
    job_function: Union[str ,None] = None
    industries: Union[str ,None] = None


def get_driver():
    '''
    Get Selenium driver
    '''
    options = webdriver.ChromeOptions()
    driver = None
    if CONFIG['ENV'] == 'dev':
        options.add_argument('--no-sandbox')
        options.add_argument('--window-size=1920,1080')
        options.add_argument('--headless')
        options.add_argument("--disable-dev-shm-usage");
        driver = webdriver.Chrome(options=options)
    if CONFIG['ENV'] == 'prod':
        options.binary_location = '/opt/chrome/chrome'
        options.add_argument('--headless')
        options.add_argument('--no-sandbox')
        options.add_argument("--disable-gpu")
        options.add_argument("--window-size=1280x1696")
        options.add_argument("--single-process")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-dev-tools")
        options.add_argument("--no-zygote")
        options.add_argument(f"--user-data-dir=/tmp/")
        options.add_argument(f"--data-path=/tmp/")
        options.add_argument(f"--disk-cache-dir=/tmp/")
        options.add_argument("--remote-debugging-port=9222")
        driver = webdriver.Chrome('/opt/chromedriver', options=options)
    return driver


def scrape_listing_links_from_query(query: str, driver):
    '''
    Given a query, returns a list of links for the listings in
    the query results

    '''

    time.sleep(1)
    driver.get(query)
    try:
        n_of_listings = int(driver.find_element(
            By.CLASS_NAME,
            RESULTS_COUNT_ELEMENT_CLASS).get_attribute('innerText')
        )
    except NoSuchElementException:
        logger.error(f'[FailedToLoadListingLinks] QueryURL:{query}\n')
        return []

    i = 2

    # Load more listings until all available listings are loaded
    while i <= int(n_of_listings/25)+1:
        driver.execute_script(
            "window.scrollTo(0, document.body.scrollHeight);")
        i += 1

        try:
            driver.find_element(
                By.XPATH, '/html/body/main/div/section/button').click()
            time.sleep(5)
        except WebDriverException:
            time.sleep(5)

    links_elements = driver.find_elements(
        By.CLASS_NAME, LISTING_LINK_ELEMENT_CLASS)
    links = [link_el.get_attribute('href').split('?')[0] for link_el in links_elements]
    return links


def get_listing_data(listing_url: str, s: requests.Session) -> Union[Listing, None]:
    '''
    Load listing page content and parse listing information,
    returning it as an object
    '''

    res = s.get(listing_url)
    html = res.text
    soup = BeautifulSoup(html, 'html.parser')

    try:
        listing = Listing(
            title=soup.find('h1', class_=LISTING_TITLE_ELEMENT_CLASS).text,
            location=soup.find(class_=LISTING_LOCATION_ELEMENT_CLASS).text,
            url=listing_url,
            company_name=soup.find(class_=LISTING_COMPANY_ELEMENT_CLASS).text,
            company_url=soup.find(class_=LISTING_COMPANY_ELEMENT_CLASS)['href'],
            description=re.sub(
                r"(\w)([A-Z])",
                r"\1 \2",
                str(soup.find(class_=LISTING_DESCRIPTION_ELEMENT_CLASS).text)
            )
        )
    except AttributeError:
        logger.error(f'[FailedToLoadListing] ListingURL:{listing_url}\n')
        return None

    time.sleep(random.choice([1.3, 1.4, 1.2, 1.6, 1.8]))
    return listing


def add_timestamp_column(df: pd.DataFrame) -> pd.DataFrame:
    '''
    Add timestamp column to dataframe
    '''
    ts = int(round(time.time() * 1000))
    df['timestamp_ms'] = ts
    return df


def build_df_from_listings(listings: Union[tuple, list]) -> pd.DataFrame:
    '''
    Build and process a listings dataframe
    '''
    logger.info('[BuildingOutputDF] Preparing listings dataframe...\n')
    listings_df = pd.DataFrame((asdict(listing) for listing in listings))
    listings_df = add_timestamp_column(listings_df)
    return listings_df


def get_listings(queries: list[str]) -> list[str]:
    '''
    Given a list of queries, returns a list of all
    the listings resulting from these queries
    '''

    driver = get_driver()
    listing_links_scraper = partial(scrape_listing_links_from_query, driver=driver)

    logger.info('[StartedListingLinksExtraction] Extracting listing links from query results pages...\n')
    links = list(chain(*list(map(listing_links_scraper, queries))))
    logger.debug(f'[FinishedListingLinksExtraction] NumberOfExtractedListingLinks:{len(links)}\n')

    # tasks = create_scraping_tasks_from_listing_links(links)
    s = requests.Session()
    s.headers.update(HTTP_HEADERS)

    logger.debug('[StartedScrapingListings] Scraping listings data...')
    listings = [get_listing_data(listing_url=url, s=s) for url in links]

    failures = listings.count(None)
    logger.debug(f'[FinishedScrapingListings] TotalNumberOfListings:{len(links)} NumberOfListingScrapingFailures:{failures} ListingsScrapingFailureRate:{failures/len(listings)}')

    return [li for li in listings if li is not None]


def store_on_s3(df: pd.DataFrame, bucket: str, prefix: str = ''):
    '''
    Store the dataframe as a parquet file on AWS S3
    '''

    s3 = boto3.client('s3')

    parquet = BytesIO()
    df.to_parquet(parquet)

    checksum = base64.b64encode(md5(parquet.getbuffer()).digest()).decode()

    file_name = prefix + datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S%z') + '.parquet'

    s3.put_object(
        Body=parquet,
        Bucket=bucket,
        ContentMD5=checksum,
        Key=file_name
    )


def lambda_handler(event: dict, context: dict):
    '''
    Lambda event handler function
    '''

    try:
        listings = get_listings(event['queries'])
        listings_df = build_df_from_listings(listings)
        store_on_s3(
            listings_df,
            event['output_s3_bucket'],
            event['output_file_prefix']
        )

    except Exception as e:
        logging.exception(e)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
                    prog='linkedin-jobs-extractor',
                    description='Scrapes job listing data from LinkedIn and stores it in S3')
    
    parser.add_argument('json_event')
    args = parser.parse_args()

    if not args.json_event:
        raise ValueError("'json_event' argument is required")
    
    event = json.loads(args.json_event)

    try:
        lambda_handler(event, dict())
    except Exception as e:
        logging.exception(e)