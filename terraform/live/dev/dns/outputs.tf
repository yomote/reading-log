output "zone_id" {
  value       = aws_route53_zone.root.zone_id
  description = "Hosted zone ID"
}

output "name_servers" {
  value       = aws_route53_zone.root.name_servers
  description = "NS records to set at the registrar"
}
