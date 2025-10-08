terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

resource "aws_security_group" "ecs_service" {
  name        = "${var.name_prefix}-ecs-sg"
  description = "Security group for ECS service"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
    description     = "Allow ALB to access app port"
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"
}

resource "aws_iam_role" "task_execution" {
  name = "${var.name_prefix}-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 現在のアカウントIDを取得
data "aws_caller_identity" "current" {}

# Secrets Managerの許可対象リソースを決定
locals {
  # 自スタックで作るシークレット名は "reading-log/dev/DATABASE_URL" なので、そのプレフィックスにマッチするワイルドカードを常に含める
  secrets_wildcard_arn = format(
    "arn:aws:secretsmanager:%s:%s:secret:reading-log/dev/*",
    var.region,
    data.aws_caller_identity.current.account_id,
  )
  secrets_resources = compact([
    local.secrets_wildcard_arn,
    var.db_password_secret_arn,
  ])
}

# Secrets 取得用のポリシードキュメント（常に作成）
data "aws_iam_policy_document" "task_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = local.secrets_resources
  }
}

# Secrets 取得用ポリシー（常に作成）
resource "aws_iam_policy" "task_secrets" {
  name        = "${var.name_prefix}-task-secrets-policy"
  description = "Allow ECS task to read secrets"
  policy      = data.aws_iam_policy_document.task_secrets.json
}

# 実行ロールにポリシーを添付（常に添付）
resource "aws_iam_role_policy_attachment" "task_secrets" {
  role       = aws_iam_role.task_execution.name
  policy_arn = aws_iam_policy.task_secrets.arn
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = 14
}

locals {
  container_name   = "${var.name_prefix}-app"
  use_split_params = true

  split_env = [
    for x in [
      var.db_host != null ? { name = "DB_HOST", value = var.db_host } : null,
      var.db_name != null ? { name = "DB_NAME", value = var.db_name } : null,
      var.db_user != null ? { name = "DB_USER", value = var.db_user } : null,
      { name = "DB_PORT", value = tostring(var.db_port) },
    ] : x if x != null
  ]

  container_env = local.split_env

  container_secrets = var.db_password_secret_arn != null ? [
    { name = "DB_PASSWORD", valueFrom = "${var.db_password_secret_arn}:password::" }
  ] : []

  container_base = {
    name      = local.container_name,
    image     = var.image,
    essential = true,
    portMappings = [{
      containerPort = var.app_port,
      hostPort      = var.app_port,
      protocol      = "tcp"
    }],
    environment = local.container_env,
    secrets     = local.container_secrets,
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name,
        awslogs-region        = var.region,
        awslogs-stream-prefix = "ecs"
      }
    },
    command = []
  }

  container_with_command = merge(local.container_base, {
    command = [
      "/bin/sh",
      "-lc",
      <<-EOS
        set -euo pipefail
        for v in DB_HOST DB_NAME DB_USER DB_PASSWORD DB_PORT; do
          if [ -z "$(printenv "$v" || true)" ]; then echo "$v is required" >&2; exit 1; fi
        done
        DB_USER_ENC=$(node -e "process.stdout.write(encodeURIComponent(process.env.DB_USER || ''))")
        DB_PASSWORD_ENC=$(node -e "process.stdout.write(encodeURIComponent(process.env.DB_PASSWORD || ''))")
        DB_NAME_ENC=$(node -e "process.stdout.write(encodeURIComponent(process.env.DB_NAME || ''))")
        DB_PORT_NUM=$(node -e "const p=process.env.DB_PORT||''; const n=parseInt(p,10); process.stdout.write(String(Number.isFinite(n)&&n>0?n:3306))")
        export DATABASE_URL="mysql://$DB_USER_ENC:$DB_PASSWORD_ENC@$DB_HOST:$DB_PORT_NUM/$DB_NAME_ENC"
        exec node server.js
      EOS
    ]
  })
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.name_prefix}-task"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  # Secret 前提のため、単純に container_base を使用
  container_definitions = jsonencode([local.container_with_command])
}

resource "aws_ecs_service" "this" {
  name            = "${var.name_prefix}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # 新しいタスク定義を確実に反映
  force_new_deployment = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = local.container_name
    container_port   = var.app_port
  }
}

resource "aws_ecs_task_definition" "migrate" {
  family                   = "${var.name_prefix}-migrate-task"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    merge(local.container_base, {
      name = "${var.name_prefix}-migrate"
      command = [
        "/bin/sh",
        "-lc",
        <<-EOC
          set -euo pipefail
          for v in DB_HOST DB_NAME DB_USER DB_PASSWORD DB_PORT; do
            if [ -z "$(printenv "$v" || true)" ]; then echo "$v is required" >&2; exit 1; fi
          done
          DB_USER_ENC=$(node -e "process.stdout.write(encodeURIComponent(process.env.DB_USER || ''))")
          DB_PASSWORD_ENC=$(node -e "process.stdout.write(encodeURIComponent(process.env.DB_PASSWORD || ''))")
          DB_NAME_ENC=$(node -e "process.stdout.write(encodeURIComponent(process.env.DB_NAME || ''))")
          DB_PORT_NUM=$(node -e "const p=process.env.DB_PORT||''; const n=parseInt(p,10); process.stdout.write(String(Number.isFinite(n)&&n>0?n:3306))")
          export DATABASE_URL="mysql://$DB_USER_ENC:$DB_PASSWORD_ENC@$DB_HOST:$DB_PORT_NUM/$DB_NAME_ENC"
          echo "[migrate] running: ${var.migration_command}" >&2
          ${var.migration_command}
          echo "[migrate] done" >&2
        EOC
      ]
    })
  ])
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "security_group_id" {
  value = aws_security_group.ecs_service.id
}

output "migration_task_definition_arn" {
  value = aws_ecs_task_definition.migrate.arn
}
