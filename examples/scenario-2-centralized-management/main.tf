# Example infrastructure resources for Scenario 2
# This demonstrates deploying resources from a management account into a target account using role assumption

resource "aws_api_gateway_rest_api" "example" {
  provider    = aws.target
  name        = "${var.project_name}-example-scenario-2-api"
  description = "Example API Gateway for ${var.environment} environment deployed via centralized management"

  tags = {
    Name        = "${var.project_name}-example-api"
    Environment = var.environment
    Project     = var.project_name
  }
}
