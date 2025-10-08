output "alb_arn" {
  value       = aws_lb.this.arn
  description = "ARN of the ALB"
}

output "alb_dns_name" {
  value       = aws_lb.this.dns_name
  description = "DNS name of the ALB"
}

output "target_group_arn" {
  value       = aws_lb_target_group.this.arn
  description = "ARN of the target group"
}

output "security_group_id" {
  value       = aws_security_group.alb.id
  description = "Security group ID for ALB"
}

output "https_listener_arn" {
  value       = aws_lb_listener.https.arn
  description = "ARN of HTTPS listener"
}

output "alb_zone_id" {
  value       = aws_lb.this.zone_id
  description = "Hosted zone ID of the ALB for alias records"
}
