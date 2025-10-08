variable "name_prefix" {
  description = "Prefix for naming resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ALB will be placed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "ingress_cidr_blocks" {
  description = "Allowed CIDR blocks for ALB ingress"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "target_group_port" {
  description = "Port for target group"
  type        = number
  default     = 3000
}

variable "health_check_path" {
  description = "Health check path for target group"
  type        = string
  default     = "/"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener (required)"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID for ALIAS record"
  type        = string
}
