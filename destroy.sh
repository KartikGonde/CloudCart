#!/usr/bin/env bash
# Delete every AWS resource created by deploy.sh (data in RDS/DynamoDB is lost).
#
# Usage:
#   ./destroy.sh           # shows the plan and asks for confirmation
#   ./destroy.sh --yes     # no prompt
set -euo pipefail

INFRA_DIR="$(cd "$(dirname "$0")" && pwd)/infra"

AUTO_APPROVE=""
if [ "${1:-}" = "--yes" ]; then
  AUTO_APPROVE="-auto-approve"
fi

if [ ! -f "$INFRA_DIR/terraform.tfstate" ]; then
  echo "No Terraform state in infra/ - nothing to destroy."
  exit 0
fi

echo "==> Destroying all resources (CloudFront and the VPC Link take ~5-10 min to delete)"
terraform -chdir="$INFRA_DIR" init -input=false >/dev/null
# shellcheck disable=SC2086 # AUTO_APPROVE is intentionally empty or a single flag
terraform -chdir="$INFRA_DIR" destroy -input=false $AUTO_APPROVE
