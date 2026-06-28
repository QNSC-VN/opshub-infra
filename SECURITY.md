# Security Policy

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Please report: **security@qnsc.vn**

You will receive acknowledgement within **48 hours** and a status update within **7 days**.

## Scope

**In scope:**
- IAM over-permissive roles or policies
- Publicly exposed infrastructure (open security groups, public S3 buckets)
- Hardcoded credentials or secrets in Terraform/OpenTofu state or code
- WAF/ALB misconfiguration leading to unprotected endpoints
- Container image vulnerabilities (critical/high CVEs)

**Out of scope:**
- Issues requiring physical access to AWS infrastructure
- Denial-of-service via cost exhaustion (report to AWS instead)

## Secure Infrastructure Practices

- All secrets are stored in AWS Secrets Manager; none are committed to VCS
- IAM roles follow least-privilege principle
- All state backends use encrypted S3 + DynamoDB locking
- Production environments require manual approval before apply
- All plan runs are logged; apply runs are audited via CloudTrail
