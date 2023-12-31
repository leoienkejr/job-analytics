resource "aws_s3_bucket" "data_lake_storage" {
  bucket = format("%s-job-analytics-data-lake-storage", local.account_id)
}

resource "aws_s3_bucket_public_access_block" "data_lake_storage_public_access_block" {
  bucket = aws_s3_bucket.data_lake_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


data "archive_file" "lambda_package_LoadJSONFromS3" {
  type             = "zip"
  source_dir      = "${path.module}/../../lambda/python/LoadJSONFromS3"
  output_file_mode = "0666"
  output_path      = "${path.module}/../../lambda/python/LoadJSONFromS3/package.zip"
}