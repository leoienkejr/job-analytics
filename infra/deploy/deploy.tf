# dev or prod
# codestar connection arn
# repo id

# Provider setup

variable aws_region {
    type            = string
}

variable aws_credentials_profile {
    type = string
}

data "aws_caller_identity" "current" {}
locals {
    account_id = data.aws_caller_identity.current.account_id
    backend_bucket = format("%s-terraform-backend", data.aws_caller_identity.current.account_id)
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


# Pipeline configuration parameters

variable env_flag {
    type        = string
    default     = "dev"
    description = "Flag to determine if production (prod) or development (dev) stack will be built"
    validation {
        condition       = var.env_flag == "dev" || var.env_flag == "prod"
        error_message   = "Value of 'env_flag' must be one of ['env', 'prod']"
    }
}

variable source_connection_name {
    type            = string
    description     = "Name of the CodeStar connection that will be used to connect with the source repository"
}

variable source_provider_type {
    type            = string
    description     = "Type of the source repository provider"
}

variable source_repository_id {
    type            = string
    description     = "ID of the repository on the provider, such as 'user/repository'"
}

variable source_branch_name {
    type        = string
    description = "Name of the branch to be set as source"
}


# Resources

resource "aws_codestarconnections_connection" "source_connection" {
    name             = var.source_connection_name
    provider_type    = var.source_provider_type
}