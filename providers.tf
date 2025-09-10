# Configura o AWS Provider
provider "aws" {
  region = "us-east-1"
  profile = var.aws_profile
  default_tags {
    tags = var.default_tags
  }
}