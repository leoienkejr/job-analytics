import boto3
import json

def lambda_handler(event, context):
    # Split the S3 path into bucket and key
    file_path = event['file_path']
    file_path = file_path.replace('s3://', '')
    bucket, key = file_path.split('/', 1)

    # Create an S3 client
    s3_client = boto3.client('s3')

    try:
        # Download the file from S3
        response = s3_client.get_object(Bucket=bucket, Key=key)
        json_content = response['Body'].read().decode('utf-8')

        # Parse JSON content
        parsed_object = json.loads(json_content)

        return parsed_object

    except Exception as e:
        print(f"Error loading and parsing file from S3: {e}")
        return None