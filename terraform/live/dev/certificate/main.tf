terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  validation_method         = "DNS"
  subject_alternative_names = var.subject_alternative_names
  tags                      = var.tags
}

resource "aws_route53_record" "cert_validation" {
  for_each = { for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => dvo }
  name     = each.value.resource_record_name
  type     = each.value.resource_record_type
  zone_id  = var.hosted_zone_id
  records  = [each.value.resource_record_value]
  ttl      = 60
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
