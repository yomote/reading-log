terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" { key = "terraform-live-dev-app.tfstate" }
}

provider "aws" { region = var.aws_region }

# ---- Locals ----
locals {
  common_tags = {
    Project = "reading-log"
    Env     = "dev"
  }
  use_external_database_url_secret = var.database_url_secret_arn != null
}

# ---- Data: ECR ----
data "aws_ecr_repository" "app" { name = "reading-log-dev" }

locals { app_image = "${data.aws_ecr_repository.app.repository_url}:${var.app_image_tag}" }

# ---- Core Networking (VPC, Subnets, etc.) ----
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "main"
    Env  = "dev"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"
  tags                    = { Name = "public-a" }
}
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2b"
  tags                    = { Name = "public-b" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-2a"
  tags              = { Name = "private-a" }
}
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-2b"
  tags              = { Name = "private-b" }
}

resource "aws_internet_gateway" "this" { vpc_id = aws_vpc.main.id }

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" { domain = "vpc" }
resource "aws_nat_gateway" "this" {
  subnet_id     = aws_subnet.public_a.id
  allocation_id = aws_eip.nat.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
}
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# ---- Secrets ----
resource "aws_secretsmanager_secret" "database_url" {
  count       = local.use_external_database_url_secret ? 0 : 1
  name        = "reading-log/dev/DATABASE_URL"
  description = "DATABASE_URL for reading-log (dev)"
}
resource "aws_secretsmanager_secret_version" "database_url" {
  count         = local.use_external_database_url_secret || var.database_url == null ? 0 : 1
  secret_id     = aws_secretsmanager_secret.database_url[0].id
  secret_string = var.database_url
  lifecycle { ignore_changes = [secret_string] }
}

# ---- ALB Module ----
module "alb" {
  source              = "../../../modules/networking/alb"
  name_prefix         = "reading-log-dev"
  vpc_id              = aws_vpc.main.id
  public_subnet_ids   = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  target_group_port   = 3000
  health_check_path   = "/"
  tags                = local.common_tags
  certificate_arn     = var.certificate_arn
  hosted_zone_id      = var.hosted_zone_id
}

resource "aws_route53_record" "app_alias" {
  zone_id = var.hosted_zone_id
  name    = var.app_fqdn
  type    = "A"
  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = false
  }
}

# ---- ECS + DB Modules ----
module "app" {
  source                  = "../../../modules/services/reading-log-app"
  name_prefix             = "reading-log-dev"
  vpc_id                  = aws_vpc.main.id
  private_subnet_ids      = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  alb_security_group_id   = module.alb.security_group_id
  target_group_arn        = module.alb.target_group_arn
  image                   = local.app_image
  app_port                = 3000
  task_cpu                = 512
  task_memory             = 1024
  database_url            = null
  database_url_secret_arn = null
  db_host                 = split(":", module.db.endpoint)[0]
  db_port                 = 3306
  db_name                 = var.db_name
  db_user                 = var.db_username
  db_password_secret_arn  = module.db.master_user_secret_arn
  region                  = var.aws_region
  tags                    = local.common_tags
}

module "db" {
  source                = "../../../modules/data-stores/mysql"
  name_prefix           = "reading-log-dev"
  vpc_id                = aws_vpc.main.id
  private_subnet_ids    = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  ecs_security_group_id = module.app.security_group_id
  db_name               = var.db_name
  username              = var.db_username
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  engine_version        = "8.0"
  tags                  = local.common_tags
}
