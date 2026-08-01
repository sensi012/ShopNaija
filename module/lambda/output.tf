output "function_arn" {
  value = aws_lambda_function.image_processor.arn
}

output "function_name" {
  value = aws_lambda_function.image_processor.function_name
}
