output "api_gateway_id" {
  description = "ID of the created API Gateway"
  value       = aws_api_gateway_rest_api.example.id
}

output "api_gateway_arn" {
  description = "ARN of the created API Gateway"
  value       = aws_api_gateway_rest_api.example.arn
}

output "api_gateway_name" {
  description = "Name of the created API Gateway"
  value       = aws_api_gateway_rest_api.example.name
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the created API Gateway"
  value       = aws_api_gateway_rest_api.example.execution_arn
}

output "deployment_region" {
  description = "AWS region where resources were deployed"
  value       = var.aws_region
}
