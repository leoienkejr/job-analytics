variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "CodeBuildServiceRole" {
  type = string
  description = "ARN of the role used by the CodeBuild project. Necessary in order to give the role permissions to interact with the ECR repositories."
}