variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-2"
}

variable "repository_name" {
  type        = string
  description = "ECR repository name"
  default     = "reading-log-dev"
}
