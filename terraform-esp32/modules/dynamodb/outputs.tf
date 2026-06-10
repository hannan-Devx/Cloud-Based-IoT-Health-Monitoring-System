output "table_arn" {
  value = aws_dynamodb_table.esp32_vitals.arn
}

output "table_name" {
  value = aws_dynamodb_table.esp32_vitals.name
}
