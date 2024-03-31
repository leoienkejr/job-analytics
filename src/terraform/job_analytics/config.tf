
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

    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
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

provider "docker" {
  host = "unix:///var/run/docker.sock"

  registry_auth {
    address = format("%s.dkr.ecr.%s.amazonaws.com", local.account_id, var.aws_region)
    username = "AWS"
    password = var.ecr_default_registry_password
  }
}