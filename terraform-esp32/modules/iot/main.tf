resource "aws_iot_thing" "esp32" {
  name = var.thing_name
}

# Auto-generate certificate (same as clicking "Auto-generate" in console)
resource "aws_iot_certificate" "esp32_cert" {
  active = true
}

# Attach certificate to Thing
resource "aws_iot_thing_principal_attachment" "esp32_attach" {
  thing     = aws_iot_thing.esp32.name
  principal = aws_iot_certificate.esp32_cert.arn
}

# IoT Policy – allows all IoT actions (same as your JSON)
resource "aws_iot_policy" "esp32_policy" {
  name = var.policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "iot:*"
      Resource = "*"
    }]
  })
}

# Attach policy to certificate
resource "aws_iot_policy_attachment" "esp32_policy_attach" {
  policy = aws_iot_policy.esp32_policy.name
  target = aws_iot_certificate.esp32_cert.arn
}
