'''
Load and validate definitions for selected pipelines

'''

import json
import functools
import operator

import boto3
from jsonschema import validate


DEFINITIONS_SCHEMA = {
    'type': 'array',
    'items': {
        'type': 'object',
        'properties': {
            'name': {
                'type': 'string'
            },
            'dbt_selector': {
                'type': 'string'
            },
            'extraction_triggers': {
                'type': 'array',
                'items': {
                    'type': 'object',
                    'properties': {
                        'extractor_type': {
                            'type': 'string'
                        },
                        'identifier': {
                            'type': 'string'
                        },
                        'parameters': {
                            'type': 'object'
                        }
                    }
                }
            }
        }
    }
}


def load_file_contents_from_s3(bucket_name: str, file_key: str) -> str:
    """
    Load a file from Amazon S3 and return its contents as a string.

    Args:
        bucket_name (str): The name of the S3 bucket.
        file_key (str): The key of the file in the S3 bucket.

    Returns:
        str: The contents of the file as a string.

    Raises:
        FileNotFoundError: If the specified file does not exist in the S3 bucket.
    """
    # Create an S3 client
    s3 = boto3.client('s3')
    
    try:
        # Get the object from S3
        response = s3.get_object(Bucket=bucket_name, Key=file_key)
        
        # Read the contents of the file
        file_contents = response['Body'].read().decode('utf-8')
        
        return file_contents
    except s3.exceptions.NoSuchKey:
        raise FileNotFoundError(f"The file '{file_key}' does not exist in the S3 bucket '{bucket_name}'.")


def get_validated_definitions(definitions: str) -> str:
    validate(instance=json.loads(definitions), schema=DEFINITIONS_SCHEMA)
    return definitions
    

def filter_selected_definitions(definitions: str, selection: list[str]) -> str:
    return list([pipeline for 
                 pipeline in json.loads(definitions) 
                 if pipeline['name'] in selection]
            )

def format_definitions_for_execution(definitions: str) -> str:
    definitions_obj = json.loads(definitions)

    selected_pipelines = list([pipeline['name'] for pipeline in definitions_obj])
    full_dbt_selector = ' '.join(list([pipeline['dbt_selector'] for pipeline in definitions]))
    extraction_triggers = list(pipeline['extraction_triggers'] for pipeline in definitions)
    extraction_triggers = functools.reduce(operator.iconcat, extraction_triggers, [])

    return json.dumps(
        {
            'selected_pipelines': selected_pipelines,
            'full_dbt_selector': full_dbt_selector,
            'extraction_triggers': extraction_triggers
        }, indent=4, sort_keys=True
    )


def lambda_handler(event: dict, context: dict) -> str:
    definitions = load_file_contents_from_s3(bucket_name=event['bucket_name'], file_key=event['file_key'])
    definitions = get_validated_definitions(definitions)
    definitions = filter_selected_definitions(definitions, selection=event['selection'])
    return format_definitions_for_execution(definitions)
