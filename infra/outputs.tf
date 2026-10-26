output "website_url" {
  description = "Open this in a browser."
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "api_url" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "aws_region" {
  value = var.aws_region
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.spa.id
}

output "frontend_bucket" {
  value = aws_s3_bucket.frontend.id
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.frontend.id
}

output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}

output "ecs_services" {
  value = [for s in aws_ecs_service.service : s.name]
}

output "ecr_registry" {
  value = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "order_shipping_queue_url" {
  value = aws_sqs_queue.order_shipping.url
}
