output "thing_arn" {
  value = aws_iot_thing.esp32.arn
}

output "certificate_arn" {
  value = aws_iot_certificate.esp32_cert.arn
}

output "certificate_pem" {
  value     = aws_iot_certificate.esp32_cert.certificate_pem
  sensitive = true
}

output "private_key" {
  value     = aws_iot_certificate.esp32_cert.private_key
  sensitive = true
}

output "public_key" {
  value     = aws_iot_certificate.esp32_cert.public_key
  sensitive = true
}
