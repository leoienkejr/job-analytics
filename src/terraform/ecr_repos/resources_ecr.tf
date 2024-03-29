resource "aws_ecr_repository" "LinkedinExtractorECRRepository" {
  name                 = "LinkedinExtractor"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}