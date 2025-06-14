# Example infrastructure resources for Scenario 1
# This demonstrates basic resources deployed in the same account as the terraform backend

resource "aws_api_gateway_rest_api" "example" {
  name        = "${var.project_name}-example-scenario-1-api"
  description = "Example API Gateway for ${var.environment} environment"

  tags = {
    Name        = "${var.project_name}-example-api"
    Environment = var.environment
    Project     = var.project_name
  }
}
