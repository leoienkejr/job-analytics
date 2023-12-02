
data "aws_caller_identity" "current" {}

locals {
    account_id = data.aws_caller_identity.current.account_id
}

terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }

  backend "s3" {}
  
}

provider "aws" {
    region = var.aws_region
    shared_credentials_files = ["~/.aws/config"]
    profile = var.aws_credentials_profile
    default_tags {
        tags = {
            Project = "job-analytics"
        }
    }
}