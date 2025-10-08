terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db-sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
    description     = "Allow ECS tasks to access MySQL"
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_db_instance" "this" {
  identifier                    = "${var.name_prefix}-mysql"
  engine                        = "mysql"
  engine_version                = var.engine_version
  instance_class                = var.instance_class
  allocated_storage             = var.allocated_storage
  db_name                       = var.db_name
  username                      = var.username
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.master_user_secret_kms_key_id

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
  storage_encrypted      = true

  backup_retention_period = 7
  deletion_protection     = false
}

output "db_endpoint" {
  value       = aws_db_instance.this.endpoint
  description = "RDS endpoint"
}

output "db_security_group_id" {
  value       = aws_security_group.db.id
  description = "Security group ID for RDS"
}
