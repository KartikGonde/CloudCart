# One-command AWS deployment (Terraform)

Automates modules 1–8 of `deployment/`, using the same architecture and resource names.

## Prerequisites

- AWS CLI with credentials (`aws sts get-caller-identity` works)
- Terraform ≥ 1.5 (`brew install hashicorp/tap/terraform`)
- Docker (running), Node.js 20+, npm

## Deploy

```bash
# from the repo root
NOTIFICATION_EMAIL=you@example.com ./deploy.sh   # email is optional
```

This takes about 20 minutes the first time. The script:

1. Writes `infra/terraform.tfvars` on the first run (region from your AWS CLI config, CPU architecture from your machine)
2. Creates the ECR repos, then builds and pushes the 4 service images
3. Runs `terraform apply`: VPC, NAT, Cognito, S3 + CloudFront, DynamoDB (seeded with `data/products.json`), RDS, internal ALB, ECS Fargate, API Gateway + VPC Link, SNS/SQS, and Parameter Store
4. Writes `frontend/react-app/src/aws-config.js` from the Terraform outputs, then builds the frontend and uploads it to S3
5. Waits for the services to become healthy and prints the website URL

Run it again after changing code. Each run pushes new image tags, and ECS rolls them out.

## Destroy

```bash
./destroy.sh
```

## Notes

- **Cost:** about $3/day while running (NAT Gateway, ALB, RDS, 4 Fargate tasks). Destroy when you're done.
- **State:** Terraform state is local (`infra/terraform.tfstate`) and contains the generated DB password. It's in `.gitignore`. Don't delete it while resources exist.
- **Logs:** `aws logs tail /ecs/order-service --follow`
- **Custom domain (module 9):** not automated.
