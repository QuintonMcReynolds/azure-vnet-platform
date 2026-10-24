#!/usr/bin/env bash
# Same steps the pipeline runs, for deploying from your laptop.
# Usage: ./scripts/deploy.sh <env> [image-tag]      e.g. ./scripts/deploy.sh dev
# Needs infra/environments/<env>.backend.hcl (see backend.hcl.example).
set -euo pipefail

ENV="${1:?environment (dev or contoso)}"
TAG="${2:-$(git rev-parse --short HEAD)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/infra"

terraform init -reconfigure -backend-config="environments/${ENV}.backend.hcl"

echo "==> Pass 1: network, registry, database, secrets"
terraform apply -auto-approve -var-file="environments/${ENV}.tfvars" -var deploy_app=false

ACR="$(terraform output -raw acr_name)"
echo "==> Building image notes-api:${TAG} in ${ACR} (ACR Tasks, no local Docker needed)"
az acr build -r "$ACR" -t "notes-api:${TAG}" --build-arg APP_VERSION="$TAG" "$ROOT/app"

echo "==> Pass 2: deploy the app"
terraform apply -auto-approve -var-file="environments/${ENV}.tfvars" -var deploy_app=true -var image_tag="$TAG"

"$ROOT/scripts/smoke-test.sh" "$(terraform output -raw resource_group)" "$(terraform output -raw container_app_name)" \
  "$(terraform output -raw app_url)" "$(terraform output -raw internal_only)" "$TAG"
