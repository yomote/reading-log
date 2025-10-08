variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-2"
}

variable "app_image_tag" {
  type        = string
  description = "Image tag"
}

variable "database_url" {
  type        = string
  description = "DATABASE_URL for the app (optional if secret ARN provided or split params used)"
  sensitive   = true
  default     = null
}

variable "database_url_secret_arn" {
  type        = string
  description = "Secrets Manager ARN holding DATABASE_URL (external)"
  default     = null
}

variable "db_name" {
  type        = string
  description = "RDS database name"
  default     = "readinglog"
}

variable "db_username" {
  type        = string
  description = "RDS master username"
}

# Domain / certificate
variable "app_fqdn" {
  type        = string
  description = "FQDN for the application (ALB + certificate)"
}

# Hosted zone ID (from separate dns stack)
variable "hosted_zone_id" {
  type        = string
  description = "Existing Route53 hosted zone ID for the root domain"
}

# ACM certificate ARN for ALB
variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listener (from certificate module)"
}
