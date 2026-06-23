# OpsHub Infrastructure (OpenTofu)

OpenTofu (≥ 1.9) configuration for the OpsHub platform on AWS. The layout mirrors
the `rally-infra` conventions: composable `modules/` consumed by per-environment
roots under `live/`.

```
modules/        reusable building blocks (network, rds, ecs-service, …)
live/
  _shared/      account-wide resources (ECR repos, GitHub OIDC deploy role)
  develop/      develop environment root
  prod/         production environment root
```

## Differences from rally-infra

OpsHub is **single-tenant** and does **not** use ElastiCache/Valkey, so there is
no `cache` module and the API/worker carry no `REDIS_URL`. Auth uses an HS256
`JWT_SECRET` (one secret) rather than an RSA key pair.

## Usage

State is stored per-environment in S3 with DynamoDB locking. Bootstrap the state
bucket/table once, then:

```bash
cd live/_shared && tofu init && tofu apply   # ECR + OIDC role first
cd ../develop   && tofu init && tofu apply
```

Set `image_tag`, `acm_cert_arn`, and the `ecr_*_url` locals after the shared
apply. Fill secret *values* in AWS Secrets Manager after the first apply
(OpenTofu only provisions the secret containers).
