# Module 6: HTTP API -> VPC Link -> internal ALB, Cognito JWT authorizer

resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${local.name}-vpc-link"
  subnet_ids         = aws_subnet.ecs[*].id
  security_group_ids = [aws_security_group.vpclink.id]
}

resource "aws_apigatewayv2_api" "main" {
  name          = "${local.name}-api"
  protocol_type = "HTTP"
  description   = "eCommerce HTTP API"

  cors_configuration {
    allow_origins = concat(["https://${aws_cloudfront_distribution.frontend.domain_name}"], var.additional_cors_origins)
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    # Headers sent by frontend/react-app/src/api.js. Authorization can't be
    # covered by a "*" wildcard in browsers, so list them explicitly.
    allow_headers = ["authorization", "content-type", "x-user-id", "x-user-email", "x-user-name"]
    max_age       = 3600
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "alb" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = aws_lb_listener.http.arn
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.main.id
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  name             = "cognito-jwt-authorizer"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
    audience = [aws_cognito_user_pool_client.spa.id]
  }
}

# Product listing is public
resource "aws_apigatewayv2_route" "products" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /products"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# Everything else requires a Cognito token
resource "aws_apigatewayv2_route" "proxy" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "ANY /{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.alb.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# CORS preflight must not require auth
resource "aws_apigatewayv2_route" "preflight" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "OPTIONS /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}
