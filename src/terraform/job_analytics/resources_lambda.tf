data "aws_iam_policy_document" "assume_role_policy_for_lambda" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "DefaultLambdaRole" {
  name               = "DefaultLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_for_lambda.json
}

resource "aws_iam_role_policy" "DefaultLambdaRole_Policy" {
  name = "DefaultLambdRolePolicy"
  role = aws_iam_role.DefaultLambdaRole.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["s3:*"]
        Effect = "Allow"
        Resource = [
          format("arn:aws:s3:::%s-job-analytics-artifacts", local.account_id)
        ]
      }
    ]
  })
}

resource "aws_lambda_function" "GetPipelineDefinitions" {
  s3_bucket     = format("%s-job-analytics-artifacts", local.account_id)
  s3_key        = "lambda_packages/GetPipelineDefinitions.zip"
  function_name = "GetPipelineDefinitions"
  role          = aws_iam_role.DefaultLambdaRole.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.12"
  timeout       = 120
  architectures = ["x86_64"]
}

