# ── SNS Topic ─────────────────────────────────────────────────
resource "aws_sns_topic" "emergency_alerts" {
  name         = "emergency-alerts"
  display_name = "ESP32 Emergency Alert System"

  tags = {
    Project = "ESP32HealthMonitor"
  }
}

# ── DynamoDB: Emergency Contacts Table ────────────────────────
resource "aws_dynamodb_table" "emergency_contacts" {
  name         = "emergency-contacts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "device_id"

  attribute {
    name = "device_id"
    type = "S"
  }

  tags = {
    Project = "ESP32HealthMonitor"
  }
}

# ── IAM Role for Emergency Lambda ─────────────────────────────
resource "aws_iam_role" "emergency_lambda_role" {
  name = "emergency-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "emergency_lambda_policy" {
  name = "emergency-lambda-policy"
  role = aws_iam_role.emergency_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Scan"]
        Resource = aws_dynamodb_table.emergency_contacts.arn
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish", "sns:Subscribe", "sns:ListSubscriptionsByTopic"]
        Resource = aws_sns_topic.emergency_alerts.arn
      },
    ]
  })
}

# ── Lambda: emergency-handler ──────────────────────────────────
data "archive_file" "emergency_handler_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/emergency_handler.py"
  output_path = "${path.module}/lambda/emergency_handler.zip"
}

resource "aws_lambda_function" "emergency_handler" {
  function_name    = "emergency-handler"
  filename         = data.archive_file.emergency_handler_zip.output_path
  source_code_hash = data.archive_file.emergency_handler_zip.output_base64sha256
  handler          = "emergency_handler.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.emergency_lambda_role.arn
  timeout          = 30

  environment {
    variables = {
      CONTACTS_TABLE = aws_dynamodb_table.emergency_contacts.name
      SNS_TOPIC_ARN  = aws_sns_topic.emergency_alerts.arn
    }
  }

  tags = {
    Project = "ESP32HealthMonitor"
  }
}

# ── API Gateway: add routes to existing API ────────────────────
# (Assumes your existing api gateway resource is: aws_apigatewayv2_api.esp32_api)

resource "aws_apigatewayv2_integration" "emergency_integration" {
  api_id = var.api_id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.emergency_handler.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_contacts" {
  api_id = var.api_id
  route_key = "POST /contacts"
  target    = "integrations/${aws_apigatewayv2_integration.emergency_integration.id}"
}

resource "aws_apigatewayv2_route" "post_trigger_emergency" {
  api_id = var.api_id
  route_key = "POST /trigger-emergency"
  target    = "integrations/${aws_apigatewayv2_integration.emergency_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw_emergency" {
  statement_id  = "AllowAPIGWInvokeEmergency"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.emergency_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "arn:aws:execute-api:ap-south-1:${var.aws_account_id}:${var.api_id}/*/*"
}

# ── Outputs ────────────────────────────────────────────────────
output "sns_topic_arn" {
  description = "SNS Topic ARN – use in Lambda env var"
  value       = aws_sns_topic.emergency_alerts.arn
}

output "contacts_endpoint" {
  value = "POST ${var.api_base_url}/contacts"
}

output "emergency_endpoint" {
  value = "POST ${var.api_base_url}/trigger-emergency"
}
