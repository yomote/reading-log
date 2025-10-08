output "alb_dns" {
  value       = module.alb.alb_dns_name
  description = "ALB DNS name"
}

output "service_name" {
  value       = module.app.service_name
  description = "ECS Service name"
}

output "db_endpoint" {
  value       = module.db.endpoint
  description = "RDS endpoint"
}
