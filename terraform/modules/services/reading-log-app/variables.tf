variable "name_prefix" {
  description = "Prefix for naming resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ECS service runs"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB to allow ingress"
  type        = string
}

variable "target_group_arn" {
  description = "Target group ARN for the service"
  type        = string
}

variable "image" {
  description = "Container image for the app"
  type        = string
}

variable "app_port" {
  description = "Application port exposed by the container"
  type        = number
  default     = 3000
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 1024
}

variable "database_url" {
  description = "Database connection URL (plain). Prefer using database_url_secret_arn."
  type        = string
  default     = null
  sensitive   = true
}

variable "database_url_secret_arn" {
  description = "Secrets Manager ARN that contains DATABASE_URL"
  type        = string
  default     = null
}

variable "region" {
  description = "AWS region for logs"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# 下記の split パラメータは DATABASE_URL シークレットを使わない構成(B方式)で利用されます。
# --- New: split DB parameters ---
variable "db_host" {
  description = "Database host (without port)"
  type        = string
  default     = null
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 3306
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = null
}

variable "db_user" {
  description = "Database username"
  type        = string
  default     = null
}

variable "db_password_secret_arn" {
  description = "Secrets Manager ARN for DB master secret (for password JSON key)"
  type        = string
  default     = null
}

variable "migration_command" {
  description = "Command executed in the dedicated migration task"
  type        = string
  default     = "npx prisma migrate deploy && npx prisma db seed || true"
}
