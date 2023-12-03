data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com", "codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_codestarconnections_connection" "source_connection" {
  name          = "github-connection"
  provider_type = "GitHub"
}

resource "aws_s3_bucket" "deployment_artifacts_bucket" {
  bucket = format("%s-job-analytics-artifacts", local.account_id)
}

resource "aws_s3_bucket_public_access_block" "deployment_artifacts_bucket_public_access_block" {
  bucket = aws_s3_bucket.deployment_artifacts_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "deployment_pipeline_role" {
  name               = "job-analytics-deployment-pipeline-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "deployment_pipeline_role_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject",
    ]

    resources = [
      aws_s3_bucket.deployment_artifacts_bucket.arn,
      "${aws_s3_bucket.deployment_artifacts_bucket.arn}/*"
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = [aws_codestarconnections_connection.source_connection.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deployment_pipeline_role_policy" {
  name   = "deployment_pipeline_role_policy"
  role   = aws_iam_role.deployment_pipeline_role.id
  policy = data.aws_iam_policy_document.deployment_pipeline_role_policy.json
}

resource "aws_codepipeline" "deployment_pipeline" {
  name     = "job-analytics-deployment-pipeline"
  role_arn = aws_iam_role.deployment_pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.deployment_artifacts_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.source_connection.arn
        FullRepositoryId     = var.source_repository_id
        BranchName           = var.source_branch_name
        DetectChanges        = true
        OutputArtifactFormat = "CODEBUILD_CLONE_REF"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = []
      version          = "1"

      configuration = {
        ProjectName = "job-analytics-build-project"
      }
    }
  }
}

resource "aws_codebuild_project" "build_project" {
  name          = "job-analytics-build-project"
  build_timeout = 30
  service_role  = aws_iam_role.codebuild_service_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  source {
    type                = "GITHUB"
    git_clone_depth     = 0
    report_build_status = false
    location            = "https://github.com/${var.source_repository_id}"
  }

  environment {
    type            = "LINUX_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    privileged_mode = true
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.deployment_artifacts_bucket.id}/codebuild_cache"
  }

  logs_config {
    cloudwatch_logs {
      group_name = "job-analytics-build-logs"
    }
  }
}

resource "aws_iam_role" "codebuild_service_role" {
  name               = "codebuild-service-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "codebuild_service_role_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = ["${aws_s3_bucket.deployment_artifacts_bucket.arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = [aws_codestarconnections_connection.source_connection.arn]
  }
}

resource "aws_iam_role_policy" "codebuild_service_role_policy_assignment" {
  role   = aws_iam_role.codebuild_service_role.id
  policy = data.aws_iam_policy_document.codebuild_service_role_policy.json
}
