variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "ap-south-1"
}

variable "iot_thing_name" {
  description = "Name of the IoT Thing"
  type        = string
  default     = "esp32-health-monitor"
}

variable "iot_policy_name" {
  description = "Name of the IoT Policy"
  type        = string
  default     = "ESP32HealthPolicy"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for vitals data"
  type        = string
  default     = "esp32-vitals"
}

variable "lambda_reader_name" {
  description = "Lambda function name for reading latest vitals"
  type        = string
  default     = "esp32-vitals-reader"
}

variable "lambda_history_name" {
  description = "Lambda function name for reading vitals history"
  type        = string
  default     = "get-vitals-history"
}

variable "api_name" {
  description = "HTTP API Gateway name"
  type        = string
  default     = "esp32-health-api"
}

variable "api_stage" {
  description = "API Gateway deployment stage"
  type        = string
  default     = "prod"
}
