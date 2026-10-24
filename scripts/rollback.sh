#!/usr/bin/env bash
# Roll back to a previous image tag (git SHA) that already exists in the registry.
# Usage: ./scripts/rollback.sh <env> <previous-tag>
set -euo pipefail
ENV="${1:?environment}"; TAG="${2:?previous image tag}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/infra"
terraform init -reconfigure -backend-config="environments/${ENV}.backend.hcl" >/dev/null
ACR="$(terraform output -raw acr_name)"
az acr repository show-tags -n "$ACR" --repository notes-api -o tsv | grep -qx "$TAG" \
  || { echo "Tag $TAG not found in $ACR"; exit 1; }
terraform apply -auto-approve -var-file="environments/${ENV}.tfvars" -var image_tag="$TAG"
"$ROOT/scripts/smoke-test.sh" "$(terraform output -raw resource_group)" "$(terraform output -raw container_app_name)" \
  "$(terraform output -raw app_url)" "$(terraform output -raw internal_only)" "$TAG"
