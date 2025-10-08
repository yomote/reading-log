variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-2"
}

variable "root_domain" {
  type        = string
  description = "Root domain to create hosted zone for (e.g. example.com)"
}
