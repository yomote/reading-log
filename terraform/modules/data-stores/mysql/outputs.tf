output "endpoint" {
  value       = aws_db_instance.this.endpoint
  description = "The connection endpoint"
}

output "security_group_id" {
  value       = aws_security_group.db.id
  description = "The RDS security group id"
}

output "master_user_secret_arn" {
  value       = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
  description = "ARN of the Secrets Manager secret that stores the master user credentials"
}
