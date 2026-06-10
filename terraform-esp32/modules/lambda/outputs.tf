output "reader_lambda_arn" {
  value = aws_lambda_function.vitals_reader.arn
}

output "reader_lambda_name" {
  value = aws_lambda_function.vitals_reader.function_name
}

output "history_lambda_arn" {
  value = aws_lambda_function.vitals_history.arn
}

output "history_lambda_name" {
  value = aws_lambda_function.vitals_history.function_name
}
