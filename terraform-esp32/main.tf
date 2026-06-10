terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────
# IoT Core – Thing + Certificate + Policy
# ─────────────────────────────────────────────
module "iot" {
  source      = "./modules/iot"
  thing_name  = var.iot_thing_name
  policy_name = var.iot_policy_name
}

# ─────────────────────────────────────────────
# DynamoDB Table
# ─────────────────────────────────────────────
module "dynamodb" {
  source     = "./modules/dynamodb"
  table_name = var.dynamodb_table_name
}

# ─────────────────────────────────────────────
# Lambda Functions
# ─────────────────────────────────────────────
module "lambda" {
  source              = "./modules/lambda"
  dynamodb_table_name = var.dynamodb_table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
  reader_func_name    = var.lambda_reader_name
  history_func_name   = var.lambda_history_name
}

# ─────────────────────────────────────────────
# API Gateway (HTTP API)
# ─────────────────────────────────────────────
module "api_gateway" {
  source               = "./modules/api_gateway"
  api_name             = var.api_name
  stage_name           = var.api_stage
  reader_lambda_arn    = module.lambda.reader_lambda_arn
  reader_lambda_name   = module.lambda.reader_lambda_name
  history_lambda_arn   = module.lambda.history_lambda_arn
  history_lambda_name  = module.lambda.history_lambda_name
}

# ─────────────────────────────────────────────
# IoT Rule → DynamoDB
# ─────────────────────────────────────────────
resource "aws_iam_role" "iot_to_db_role" {
  name = "ESP32ToDBRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "iot.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "iot_dynamo_policy" {
  name = "IoTDynamoWritePolicy"
  role = aws_iam_role.iot_to_db_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:PutItem"]
      Resource = module.dynamodb.table_arn
    }]
  })
}

resource "aws_iot_topic_rule" "esp32_vitals_rule" {
  name        = "esp32_vitals_rule"
  enabled     = true
  sql         = "SELECT * FROM 'esp32/health-vitals'"
  sql_version = "2016-03-23"

  dynamodbv2 {
    role_arn = aws_iam_role.iot_to_db_role.arn

    put_item {
      table_name = var.dynamodb_table_name
    }
  }

  depends_on = [module.dynamodb]
}
