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