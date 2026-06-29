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

## Shared modules

This repo composes versioned modules from
[`qnsc-tf-modules`](https://github.com/QNSC-VN/qnsc-tf-modules) — there are no
local `modules/`. Each is pinned by a per-module tag:

```hcl
module "network" {
  source = "git::https://github.com/QNSC-VN/qnsc-tf-modules.git//modules/network?ref=network-v1.0.0"
}
```

## Dependency updates

| Tool | Updates | Config |
| :--- | :------ | :----- |
| **Renovate** | Shared Terraform module pins (`?ref=<module>-vX.Y.Z`) | [`renovate.json`](./renovate.json) |
| **Dependabot** | GitHub Actions pins (`uses: …@v1`) | `.github/dependabot.yml` |

Renovate (not Dependabot) handles the *per-module prefixed* tags
(`cdn-v1.0.0`, `network-v1.0.0`); its `regex` versioning `compatibility` group
keeps each module updating within its own prefix.

> ⚠️ Renovate is a GitHub App — install it on the `QNSC-VN` org for
> `renovate.json` to take effect.
