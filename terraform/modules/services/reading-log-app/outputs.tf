output "cluster_id" {
  value       = aws_ecs_cluster.this.id
  description = "ECS Cluster ID"
}

output "service_id" {
  value       = aws_ecs_service.this.id
  description = "ECS Service ID"
}
