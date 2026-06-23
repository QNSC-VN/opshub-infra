terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  backend "s3" {
    bucket         = "qncs-tofu-state"
    key            = "opshub/develop/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "qncs-tofu-locks"
  }
}

provider "aws" {
  region = "ap-southeast-1"
  default_tags {
    tags = {
      Project     = "opshub"
      Environment = "develop"
      ManagedBy   = "opentofu"
    }
  }
}

locals {
  env    = "develop"
  name   = "opshub-develop"
  region = "ap-southeast-1"
  azs    = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]

  ecr_registry   = "${var.ecr_account_id}.dkr.ecr.${local.region}.amazonaws.com"
  ecr_api_url    = "${local.ecr_registry}/opshub-api:${var.image_tag}"
  ecr_worker_url = "${local.ecr_registry}/opshub-worker:${var.image_tag}"
}

# ── Networking ────────────────────────────────────────────────────────────────
module "network" {
  source = "../../modules/network"

  name                 = local.name
  region               = local.region
  azs                  = local.azs
  vpc_cidr             = "10.20.0.0/16"
  public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
  private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24", "10.20.12.0/24"]
  data_subnet_cidrs    = ["10.20.20.0/24", "10.20.21.0/24", "10.20.22.0/24"]
  multi_az_nat         = false
  app_port             = 3000
  tags                 = { Environment = local.env }
}

# ── Secrets (containers only; values set out-of-band) ─────────────────────────
module "secrets" {
  source       = "../../modules/secrets"
  prefix       = "opshub/${local.env}"
  secret_names = ["db-url", "jwt-secret"]
  tags         = { Environment = local.env }
}

# ── RDS PostgreSQL 18 ─────────────────────────────────────────────────────────
module "rds" {
  source = "../../modules/rds"

  identifier               = local.name
  subnet_ids               = module.network.data_subnet_ids
  security_group_id        = module.network.sg_rds_id
  instance_class           = "db.t4g.medium"
  allocated_storage_gb     = 20
  max_allocated_storage_gb = 100
  multi_az                 = false
  deletion_protection      = false
  backup_retention_days    = 3
  tags                     = { Environment = local.env }
}

# ── Messaging (SQS outbox + SNS) ──────────────────────────────────────────────
module "messaging" {
  source = "../../modules/messaging"
  prefix = local.name
  tags   = { Environment = local.env }
}

# ── ALB ───────────────────────────────────────────────────────────────────────
resource "aws_lb" "this" {
  name                       = local.name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [module.network.sg_alb_id]
  subnets                    = module.network.public_subnet_ids
  enable_deletion_protection = false
  drop_invalid_header_fields = true
  tags                       = { Name = local.name, Environment = local.env }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_cert_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ── ECS cluster ───────────────────────────────────────────────────────────────
module "ecs_cluster" {
  source = "../../modules/ecs-cluster"
  name   = local.name
  tags   = { Environment = local.env }
}

# ── API service ───────────────────────────────────────────────────────────────
module "api" {
  source = "../../modules/ecs-service"

  service_name = "api"
  cluster_name = module.ecs_cluster.cluster_name
  cluster_arn  = module.ecs_cluster.cluster_arn
  image_uri    = local.ecr_api_url
  region       = local.region

  cpu            = 512
  memory         = 1024
  container_port = 3000

  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.private_subnet_ids
  security_group_id = module.network.sg_app_id

  desired_count = 1
  min_count     = 1
  max_count     = 3

  attach_alb        = true
  alb_listener_arn  = aws_lb_listener.https.arn
  alb_priority      = 100
  alb_path_patterns = ["/*"]
  health_check_path = "/v1/healthz"

  secret_arns = values(module.secrets.secret_arns)
  secrets = [
    { name = "DATABASE_URL", secret_arn = module.secrets.secret_arns["db-url"] },
    { name = "JWT_SECRET", secret_arn = module.secrets.secret_arns["jwt-secret"] },
  ]
  environment_vars = [
    { name = "NODE_ENV", value = "production" },
    { name = "PORT", value = "3000" },
    { name = "AWS_REGION", value = local.region },
    { name = "SQS_OUTBOX_URL", value = module.messaging.outbox_queue_url },
  ]

  sqs_queue_arns = values(module.messaging.queue_arns)
  sns_topic_arns = values(module.messaging.topic_arns)
  tags           = { Environment = local.env, Service = "api" }
}

# ── Worker service ────────────────────────────────────────────────────────────
module "worker" {
  source = "../../modules/ecs-service"

  service_name = "worker"
  cluster_name = module.ecs_cluster.cluster_name
  cluster_arn  = module.ecs_cluster.cluster_arn
  image_uri    = local.ecr_worker_url
  region       = local.region

  cpu    = 256
  memory = 512

  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.private_subnet_ids
  security_group_id = module.network.sg_app_id

  desired_count = 1
  min_count     = 1
  max_count     = 2

  attach_alb = false

  secret_arns = values(module.secrets.secret_arns)
  secrets = [
    { name = "DATABASE_URL", secret_arn = module.secrets.secret_arns["db-url"] },
    { name = "JWT_SECRET", secret_arn = module.secrets.secret_arns["jwt-secret"] },
  ]
  environment_vars = [
    { name = "NODE_ENV", value = "production" },
    { name = "AWS_REGION", value = local.region },
    { name = "SQS_OUTBOX_URL", value = module.messaging.outbox_queue_url },
  ]

  sqs_queue_arns = values(module.messaging.queue_arns)
  sns_topic_arns = values(module.messaging.topic_arns)
  tags           = { Environment = local.env, Service = "worker" }
}

# ── WAF ───────────────────────────────────────────────────────────────────────
module "waf" {
  source     = "../../modules/waf"
  name       = local.name
  alb_arn    = aws_lb.this.arn
  rate_limit = 2000
  tags       = { Environment = local.env }
}
# ── CDN (S3 + CloudFront) — opshub-web SPA ─────────────────────────────────────
# Prerequisites:
#   1. Create ACM cert for the web domain in us-east-1 (CloudFront requirement)
#   2. Pass its ARN as web_acm_cert_arn in tfvars
#   3. After apply: set S3_BUCKET + CLOUDFRONT_ID as GitHub env vars for opshub-web
module "cdn" {
  source       = "../../modules/cdn"
  name         = "opshub-web-develop"
  acm_cert_arn = var.web_acm_cert_arn
  aliases      = []   # set to ["app-dev.opshub.qncs.io"] once DNS is configured
  price_class  = "PriceClass_200"
  tags         = { Environment = local.env, Service = "web" }
}