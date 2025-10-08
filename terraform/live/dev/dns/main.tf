terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" { key = "terraform-live-dev-dns.tfstate" }
}

provider "aws" { region = var.aws_region }

locals {
  zone_root = var.root_domain
}

resource "aws_route53_zone" "root" {
  name = local.zone_root
}
