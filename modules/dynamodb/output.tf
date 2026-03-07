output "db_arn" {
  value = aws_dynamodb_table.GreetingLogs.arn
}

output "db_replica" {
  value = aws_dynamodb_table.GreetingLogs.replica
}

output "primary_table_arn" {
  value = aws_dynamodb_table.GreetingLogs.arn
}

output "replica_arns_list" {
  value = local.replica_arns
}

locals {
  replica_arns = [
    for r in aws_dynamodb_table.GreetingLogs.replica :
    replace(aws_dynamodb_table.GreetingLogs.arn, data.aws_region.current.name, r.region_name)
  ]
}