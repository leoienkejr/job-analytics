resource "aws_ecr_repository" "LinkedinExtractor_ECRRepository" {
  name                 = "linkedin-extractor"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}