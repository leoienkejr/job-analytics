
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}

}

# Run 'export AWS_PROFILE=${PROFILE NAME}' when running locally

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project = "job-analytics"
    }
  }
}