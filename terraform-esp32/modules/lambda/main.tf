# ─────────────────────────────────────────────
# ZIP the Lambda source code at plan time
# ─────────────────────────────────────────────
data "archive_file" "vitals_reader_zip" {
  type        = "zip"
  source_dir  = "${path.module}/functions/vitals_reader"
  output_path = "${path.module}/functions/vitals_reader.zip"
}

data "archive_file" "vitals_history_zip" {
  type        = "zip"
  source_dir  = "${path.module}/functions/vitals_history"
  output_path = "${path.module}/functions/vitals_history.zip"
}

# ─────────────────────────────────────────────
# Shared IAM execution role
# ─────────────────────────────────────────────
resource "aws_iam_role" "lambda_exec_role" {
  name = "esp32-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDB Full Access (matches your console setup)
resource "aws_iam_role_policy_attachment" "lambda_dynamo" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# ─────────────────────────────────────────────
# Lambda: esp32-vitals-reader
# ─────────────────────────────────────────────
resource "aws_lambda_function" "vitals_reader" {
  function_name    = var.reader_func_name
  filename         = data.archive_file.vitals_reader_zip.output_path
  source_code_hash = data.archive_file.vitals_reader_zip.output_base64sha256
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_exec_role.arn
  timeout          = 30

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
    }
  }

  tags = {
    Project = "ESP32HealthMonitor"
  }
}

# ─────────────────────────────────────────────
# Lambda: get-vitals-history
# ─────────────────────────────────────────────
resource "aws_lambda_function" "vitals_history" {
  function_name    = var.history_func_name
  filename         = data.archive_file.vitals_history_zip.output_path
  source_code_hash = data.archive_file.vitals_history_zip.output_base64sha256
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_exec_role.arn
  timeout          = 30

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
    }
  }

  tags = {
    Project = "ESP32HealthMonitor"
  }
}
