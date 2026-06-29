output "alb_dns_name" { value = aws_lb.this.dns_name }
output "rds_endpoint" { value = module.rds.endpoint }
output "rds_master_secret_arn" { value = module.rds.master_secret_arn }
output "outbox_queue_url" { value = module.messaging.queue_urls["outbox"] }
output "cluster_name" { value = module.ecs_cluster.cluster_name }
output "ecs_migrator_task_def" { value = aws_ecs_task_definition.migrator.family }
output "migrator_subnet_id" { value = module.network.private_subnet_ids[0] }
output "migrator_sg_id" { value = module.network.sg_app_id }
