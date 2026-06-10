# ─────────────────────────────────────────────
# HTTP API
# ─────────────────────────────────────────────
resource "aws_apigatewayv2_api" "esp32_api" {
  name          = var.api_name
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }
}

# ─────────────────────────────────────────────
# Stage: prod (auto-deploy)
# ─────────────────────────────────────────────
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.esp32_api.id
  name        = var.stage_name
  auto_deploy = true
}

# ─────────────────────────────────────────────
# Integration: GET /vitals → esp32-vitals-reader
# ─────────────────────────────────────────────
resource "aws_apigatewayv2_integration" "reader_integration" {
  api_id                 = aws_apigatewayv2_api.esp32_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.reader_lambda_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_vitals" {
  api_id    = aws_apigatewayv2_api.esp32_api.id
  route_key = "GET /vitals"
  target    = "integrations/${aws_apigatewayv2_integration.reader_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw_reader" {
  statement_id  = "AllowAPIGWInvokeReader"
  action        = "lambda:InvokeFunction"
  function_name = var.reader_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.esp32_api.execution_arn}/*/*"
}

# ─────────────────────────────────────────────
# Integration: GET /history → get-vitals-history
# ─────────────────────────────────────────────
resource "aws_apigatewayv2_integration" "history_integration" {
  api_id                 = aws_apigatewayv2_api.esp32_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.history_lambda_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_history" {
  api_id    = aws_apigatewayv2_api.esp32_api.id
  route_key = "GET /history"
  target    = "integrations/${aws_apigatewayv2_integration.history_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw_history" {
  statement_id  = "AllowAPIGWInvokeHistory"
  action        = "lambda:InvokeFunction"
  function_name = var.history_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.esp32_api.execution_arn}/*/*"
}
