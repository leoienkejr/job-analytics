variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "env_flag" {
  type        = string
  default     = "dev"
  description = "Flag to determine if production (prod) or development (dev) stack will be built"
  validation {
    condition     = var.env_flag == "dev" || var.env_flag == "prod"
    error_message = "Value of 'env_flag' must be one of ['env', 'prod']"
  }
}

variable "source_repository_id" {
  type = string

  description = "ID of the repository on the provider, such as 'user/repository'"
}

variable "source_branch_name" {
  type        = string
  default     = "dev"
  description = "Name of the branch to be set as source"
}