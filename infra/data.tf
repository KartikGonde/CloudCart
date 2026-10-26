# Module 4: DynamoDB (products, cart), RDS PostgreSQL (users, orders), Parameter Store config

resource "aws_dynamodb_table" "products" {
  name         = "${local.name}-products"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "product_id"

  attribute {
    name = "product_id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "cart" {
  name         = "${local.name}-cart"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }
}

# Sample catalog from data/products.json, with image URLs pointed at this CloudFront distribution
resource "aws_dynamodb_table_item" "products" {
  for_each = { for p in jsondecode(file("${path.module}/../data/products.json")) : p.product_id => p }

  table_name = aws_dynamodb_table.products.name
  hash_key   = aws_dynamodb_table.products.hash_key

  item = jsonencode({
    product_id  = { S = each.value.product_id }
    name        = { S = each.value.name }
    description = { S = each.value.description }
    price       = { N = tostring(each.value.price) }
    stock       = { N = tostring(each.value.stock) }
    category    = { S = each.value.category }
    image_url   = { S = "https://${aws_cloudfront_distribution.frontend.domain_name}/images/products/${each.value.product_id}.jpg" }
  })

  # Placing orders decrements stock; don't reset it on the next apply
  lifecycle {
    ignore_changes = [item]
  }
}

resource "random_password" "db" {
  length = 24
  # RDS disallows / @ " and space in the master password
  override_special = "!#$%^&*()-_=+[]{}:?"
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id
}

resource "aws_db_instance" "main" {
  identifier     = "${local.name}db-instance"
  engine         = "postgres"
  instance_class = var.db_instance_class
  db_name        = "ecommercedb"
  username       = "postgres"
  password       = random_password.db.result

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false

  # Dev/test settings: no backups, no final snapshot, so destroy is quick and free
  backup_retention_period      = 0
  skip_final_snapshot          = true
  deletion_protection          = false
  performance_insights_enabled = false
  apply_immediately            = true
}

resource "aws_ssm_parameter" "region" {
  name  = "${local.ssm_prefix}/aws/region"
  type  = "String"
  value = var.aws_region
}

resource "aws_ssm_parameter" "db_host" {
  name  = "${local.ssm_prefix}/db/host"
  type  = "String"
  value = aws_db_instance.main.address
}

resource "aws_ssm_parameter" "db_password" {
  name  = "${local.ssm_prefix}/db/password"
  type  = "SecureString"
  value = random_password.db.result
}

# All services sit behind the same internal ALB, which routes by path
resource "aws_ssm_parameter" "service_url" {
  for_each = toset(["user-service-url", "cart-service-url", "product-service-url"])

  name  = "${local.ssm_prefix}/${each.value}"
  type  = "String"
  value = "http://${aws_lb.internal.dns_name}"
}

resource "aws_ssm_parameter" "sns_topic_arn" {
  name  = "${local.ssm_prefix}/sns/topic-arn"
  type  = "String"
  value = aws_sns_topic.order_events.arn
}
