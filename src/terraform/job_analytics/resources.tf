data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

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

resource "aws_iam_role" "lambda_execution_role_LoadJSONFromS3" {
  name               = "lambda_LoadJSONFromS3_execution_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "lambda_execution_role_policy_LoadJSONFromS3" {
  statement {
    effect = "Allow"

    actions = [
      "logs:*",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:Get*",
      "s3:List*",
      "s3:Describe*"
    ]

    resources = [
      "arn:aws:s3:::${local.account_id}-job-analytics-artifacts",
      "arn:aws:s3:::${local.account_id}-job-analytics-artifacts/*"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_LoadJSONFromS3_execution_role_policy" {
  name   = "lambda_LoadJSONFromS3_execution_role_policy"
  role   = aws_iam_role.lambda_execution_role_LoadJSONFromS3.id
  policy = data.aws_iam_policy_document.lambda_execution_role_policy_LoadJSONFromS3.json
}

# data "archive_file" "lambda_package_LoadJSONFromS3" {
#   type             = "zip"
#   source_dir       = "${path.module}/../../lambda/python/LoadJSONFromS3"
#   output_file_mode = "0666"
#   output_path      = "${path.module}/../../lambda/python/LoadJSONFromS3/package.zip"
# }

# resource "aws_lambda_function" "lambda_function_LoadJSONFromS3" {
#   function_name = "LoadJSONFromS3"
#   role          = aws_iam_role.lambda_execution_role_LoadJSONFromS3.arn

#   filename         = "${path.module}/../../lambda/python/LoadJSONFromS3/package.zip"
#   source_code_hash = filebase64sha256("src/lambda/python/LoadJSONFromS3/package.zip")
#   handler          = "main.lambda_handler"
#   runtime          = "python3.11"
#   timeout          = 900

#   environment {
#     variables = {
#       ENV_VALUES = jsonencode({
#         AWS_ACCOUNT_ID = "${local.account_id}"
#       })
#     }
#   }

# }