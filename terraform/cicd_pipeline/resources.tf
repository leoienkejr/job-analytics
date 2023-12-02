data "aws_iam_policy_document" "codepipeline_assume_role_policy" {
  statement {
    effect ="Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_codestarconnections_connection" "source_connection" {
  name          = var.source_connection_name
  provider_type = var.source_provider_type
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
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role_policy.json
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

