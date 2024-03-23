'''
Builds or updates zipped package stored on S3 from local source directories

'''

import argparse
import hashlib
import subprocess
import zipfile
from pathlib import Path
from urllib.parse import urlparse
from dataclasses import dataclass

import boto3


@dataclass
class Package:
    S3PackageFile: str
    SourceDir: str
    LocalPackageFile: str | None


def get_subdirectories(path: str) -> list:
    """
    Return a list of all subdirectories in the given path.

    :param path: The path to the directory to search for subdirectories.
    :return: A list of subdirectories in the given path.
    :raises ValueError: If the provided path is not a valid directory.
    """
    path = Path(path).resolve()
    if not path.is_dir():
        raise ValueError('Provided path is not a valid directory')

    subdirectories = [str(item) for item in path.iterdir() if item.is_dir()]
    return subdirectories


def cumulative_hash(directory_path: str) -> str:
    """
    Calculate a cumulative hash of the files contained in the directory and its subdirectories.

    :param directory_path: The path to the directory to hash.
    :return: The cumulative hash of the directory.
    """
    def hash_file(file_path: Path) -> str:
        """Calculate the hash of a file."""
        hasher = hashlib.sha256()
        with open(file_path, 'rb') as f:
            while chunk := f.read(65536):  # Read in 64k chunks
                hasher.update(chunk)
        return hasher.hexdigest()

    def hash_directory(directory: Path) -> str:
        """Calculate the hash of a directory and its contents."""
        hasher = hashlib.sha256()
        for path in sorted(directory.rglob('*')):
            if path.is_file():
                relative_path = path.relative_to(directory)
                hasher.update(str(relative_path).encode())
                hasher.update(hash_file(path).encode())
        return hasher.hexdigest()

    directory_path = Path(directory_path)
    if not directory_path.is_dir():
        raise ValueError('Provided path is not a valid directory')

    return hash_directory(directory_path)


def match_source_dirs_to_package_files(s3_destination_prefix: str, source_dirs: list[str]) -> list[Package]:
    '''
    Generate Package instances from a list of source directory paths

    :param s3_destination_prefix: Prefix with which packages are stored on S3
    :param source_dirs: Source directories
    :return: Package items
    '''

    packages = []
    for d in source_dirs:
        dir_name = Path(d).name
        s3_package_file = s3_destination_prefix + dir_name + '.zip'
        packages.append(Package(S3PackageFile=s3_package_file, SourceDir=d, LocalPackageFile=None))
    return packages


def parse_s3_url(s3_url: str) -> tuple[str, str]:
    '''
    Parses a full S3 URL and returns the bucket name and object key as separate strings

    :param s3_url: Full S3 URL
    :return: Bucket name and object key
    '''

    parsed_url = urlparse(s3_url)
    if parsed_url.scheme != 's3':
        raise ValueError("Not an S3 URL")
    bucket_name = parsed_url.netloc
    key = parsed_url.path.lstrip('/')
    return bucket_name, key


def should_build_package(package: Package) -> bool:
    ''' 
    Determines if a package needs to be built (or rebuilt) by comparing
    the cumulative hash of the source directory and the hash stored in packge
    object metadata in S3


    :param package: Package instance representing the package to be evaluated
    '''

    bucket_name, object_key = parse_s3_url(s3_url=package.S3PackageFile)
    print(bucket_name, object_key)

    s3 = boto3.client('s3')

    try:
        response = s3.head_object(Bucket=bucket_name, Key=object_key)
        metadata = response['Metadata']

        if metadata.get('source-hash') == cumulative_hash(directory_path=package.SourceDir):
            return False
        return True
    except s3.exceptions.ClientError as e:
        if e.response['Error']['Code'] == '404':
            return True
        else:
            raise

def zip_directory(directory_path, zip_filename):
    directory_path = Path(directory_path)
    with zipfile.ZipFile(zip_filename, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for file_path in directory_path.glob('**/*'):
            if file_path.is_file():
                zipf.write(file_path, file_path.relative_to(directory_path))


def upload_file_to_s3(s3_url: str, file_path: str, metadata: dict = None) -> None:
    """
    Upload a file to Amazon S3 using multipart upload and a checksum.

    :param s3_url: The full S3 object URL specifying the bucket name and object key.
    :param file_path: The local file path of the file to upload.
    """

    bucket_name, key = parse_s3_url(s3_url)

    # Create a Boto3 client for S3
    s3 = boto3.client('s3')

    # Calculate the checksum of the file
    with open(file_path, 'rb') as f:
        s3.upload_fileobj(f, bucket_name, key, ExtraArgs={'Metadata': metadata} if metadata else None)
        print(f'File uploaded successfully to S3://{bucket_name}/{key}')


def build_and_upload_package(package: Package):
    ''' 
    Builds a package from the source directory and uploads it to S3

    :param package: Package instance representing the package
    '''

    source_dir = Path(package.SourceDir)
    source_dir_hash = cumulative_hash(directory_path=package.SourceDir)
    requirements_file = source_dir / 'requirements.txt'
    zip_file = Path(str(source_dir) + '.zip')
    package.LocalPackageFile = zip_file
    

    if requirements_file.exists():
        p = subprocess.run(['pip', 'install', '--no-input', '-qqq', '-r', str(requirements_file), '-t', str(source_dir)], check=True)

    zip_directory(source_dir, package.LocalPackageFile)
    upload_file_to_s3(
        s3_url=package.S3PackageFile,
        file_path=package.LocalPackageFile,
        metadata={
            'source-hash': source_dir_hash
        })
    

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='build_zipped_packages')

    parser.add_argument('-s', '--source_dir', required=True, help='Directory containing package source directories')
    parser.add_argument('-d', '--s3_destination_prefix', required=True, help='Prefix to the package files stored on S3')
    args = parser.parse_args()

    s3_destination_prefix = args.s3_destination_prefix if args.s3_destination_prefix.endswith('/') else (args.s3_destination_prefix + '/')
    source_dirs = get_subdirectories(path=args.source_dir)
    packages = match_source_dirs_to_package_files(s3_destination_prefix=s3_destination_prefix, source_dirs=source_dirs)
    packages_to_build = [pkg for pkg in packages if should_build_package(pkg)]

    for pkg in packages_to_build:
        build_and_upload_package(pkg)