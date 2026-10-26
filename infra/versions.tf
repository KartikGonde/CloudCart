terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "ecommerce"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Resource names match the manual guides in deployment/; the service code
  # also hardcodes the "ecommerce" table names and Parameter Store prefix.
  name       = "ecommerce"
  account_id = data.aws_caller_identity.current.account_id
  azs        = slice(data.aws_availability_zones.available.names, 0, 2)

  # Services read their config from /ecommerce/<ENVIRONMENT>/... in Parameter Store
  ssm_prefix = "/ecommerce/${var.environment}"

  services = {
    product-service = { port = 8001, path = "/products*", priority = 1 }
    cart-service    = { port = 8002, path = "/cart*", priority = 2 }
    user-service    = { port = 8003, path = "/users*", priority = 3 }
    order-service   = { port = 8004, path = "/orders*", priority = 4 }
  }
}
