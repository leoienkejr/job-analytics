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