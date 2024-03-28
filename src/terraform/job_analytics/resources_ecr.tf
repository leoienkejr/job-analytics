resource "aws_ecr_repository" "LinkedinExtractorECRRepository" {
  name                 = "LinkedinExtractor"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

data "aws_iam_policy_document" "LinkedinExtractorECRRepository_PolicyDoc" {
  statement {
    sid = "1"

    actions = [
      "ecr:*",
    ]

    resources = [
      var.CodeBuildServiceRole
    ]
  }

}


resource "aws_ecr_repository_policy" "foopolicy" {
  repository = aws_ecr_repository.LinkedinExtractorECRRepository.name

  policy = aws_iam_policy_document.LinkedinExtractorECRRepository_PolicyDoc.json
}