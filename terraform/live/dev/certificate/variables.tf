variable "domain_name" {
  type        = string
  description = "Primary domain name for the ACM certificate (e.g. app.example.com)"
}

variable "subject_alternative_names" {
  type        = list(string)
  description = "Additional SANs for the certificate"
  default     = []
}

variable "hosted_zone_id" {
  type        = string
  description = "Route53 hosted zone ID for DNS validation"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to ACM certificate"
  default     = {}
}
