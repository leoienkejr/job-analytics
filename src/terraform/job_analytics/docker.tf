resource "docker_image" "linkedin_extractor_image" {
  name = format("%s.dkr.ecr.%s.amazonaws.com/linkedin-extractor:latest", local.account_id, var.aws_region)

  build {
    context = "../../images/linkedin-extractor/"
    cache_from = [
      format("%s.dkr.ecr.%s.amazonaws.com/linkedin-extractor:latest", local.account_id, var.aws_region)
    ]
  }

  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "../../images/linkedin-extractor/*") : filesha1(f)]))
  }
}

resource "docker_registry_image" "linkedin_extractor_registry_image" {
  name          = docker_image.linkedin_extractor_image.name
  keep_remotely = false

  triggers = {
    image_digest = docker_image.linkedin_extractor_image.repo_digest
  }
}