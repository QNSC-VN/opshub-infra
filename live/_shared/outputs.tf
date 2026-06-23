output "ecr_repository_urls"    { value = module.ecr.repository_urls }
output "deploy_role_arn"         { value = module.iam_oidc.deploy_role_arn }
output "web_deploy_role_arns"    { value = { for k, v in aws_iam_role.web_deploy : k => v.arn } }
