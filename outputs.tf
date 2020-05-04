output "ecs_cluster" {
  value = aws_ecs_cluster.this
}

output "secretsmanager_secret" {
  value = aws_secretsmanager_secret.this
}
