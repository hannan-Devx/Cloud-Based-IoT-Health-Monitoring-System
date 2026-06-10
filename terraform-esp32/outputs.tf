output "iot_thing_arn" {
  description = "ARN of the IoT Thing"
  value       = module.iot.thing_arn
}

output "iot_certificate_arn" {
  description = "ARN of the IoT Certificate (attach to device)"
  value       = module.iot.certificate_arn
}

output "iot_certificate_pem" {
  description = "Certificate PEM – save as device.crt"
  value       = module.iot.certificate_pem
  sensitive   = true
}

output "iot_private_key" {
  description = "Private key PEM – save as private.key"
  value       = module.iot.private_key
  sensitive   = true
}

output "iot_public_key" {
  description = "Public key PEM"
  value       = module.iot.public_key
  sensitive   = true
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.dynamodb.table_name
}

output "api_endpoint" {
  description = "Base URL for the HTTP API"
  value       = module.api_gateway.api_endpoint
}

output "vitals_url" {
  description = "Full URL to fetch latest vitals"
  value       = "${module.api_gateway.api_endpoint}/vitals"
}

output "history_url" {
  description = "Full URL to fetch vitals history"
  value       = "${module.api_gateway.api_endpoint}/history"
}
