output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint — use to connect from ASG/Flowise"
  value       = module.database.db_endpoint
  sensitive   = true
}

output "rds_db_name" {
  description = "Database name"
  value       = module.database.db_name
}