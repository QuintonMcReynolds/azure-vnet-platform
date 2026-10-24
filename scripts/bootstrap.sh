#!/usr/bin/env bash
# One-time setup. Run from your laptop after `az login`.
#  1. Creates a storage account for Terraform state.
#  2. Creates an Entra ID app registration that GitHub Actions logs in as
#     (OpenID Connect, so no client secret is ever stored).
#  3. Prints the values to save as GitHub repository secrets.
#
# Usage: ./scripts/bootstrap.sh <github-owner>/<repo-name> [region]
set -euo pipefail

REPO="${1:?usage: bootstrap.sh <github-owner>/<repo-name> [region]}"
LOCATION="${2:-eastus2}"
STATE_RG="rg-notes-tfstate"
STATE_SA="stnotestf$(openssl rand -hex 3)"
APP_NAME="gh-notes-deployer"

SUB_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
ME="$(az ad signed-in-user show --query id -o tsv)"

echo "==> Subscription: $SUB_ID"

echo "==> Registering resource providers (one time, can take a few minutes)"
for ns in Microsoft.App Microsoft.ContainerRegistry Microsoft.DBforPostgreSQL Microsoft.KeyVault \
          Microsoft.OperationalInsights Microsoft.Network Microsoft.ManagedIdentity Microsoft.Insights; do
  az provider register --namespace "$ns" --wait >/dev/null
done

echo "==> Terraform state storage: $STATE_SA"
az group create -n "$STATE_RG" -l "$LOCATION" -o none
az storage account create -n "$STATE_SA" -g "$STATE_RG" -l "$LOCATION" \
  --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false \
  --allow-shared-key-access false -o none
SA_ID="$(az storage account show -n "$STATE_SA" -g "$STATE_RG" --query id -o tsv)"
az role assignment create --assignee "$ME" --role "Storage Blob Data Contributor" --scope "$SA_ID" -o none
sleep 30
az storage container create -n tfstate --account-name "$STATE_SA" --auth-mode login -o none

echo "==> GitHub Actions identity: $APP_NAME"
APP_ID="$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)"
az ad sp create --id "$APP_ID" -o none 2>/dev/null || true
SP_ID="$(az ad sp show --id "$APP_ID" --query id -o tsv)"

# Trust tokens from the main branch, pull requests, and the two GitHub environments.
for subject in "repo:${REPO}:ref:refs/heads/main" "repo:${REPO}:pull_request" \
               "repo:${REPO}:environment:dev" "repo:${REPO}:environment:contoso"; do
  name="$(echo "$subject" | tr ':/' '--' | cut -c1-120)"
  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"${name}\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"${subject}\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" -o none
done

# Contributor creates resources; RBAC Administrator lets Terraform grant the app's
# managed identity AcrPull and Key Vault access. Scope down further for production.
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "Contributor" --scope "/subscriptions/$SUB_ID" -o none
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "Role Based Access Control Administrator" --scope "/subscriptions/$SUB_ID" -o none
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" --scope "$SA_ID" -o none

cat <<EOF

Done. Add these as GitHub repository secrets (Settings > Secrets and variables > Actions):

  AZURE_CLIENT_ID        $APP_ID
  AZURE_TENANT_ID        $TENANT_ID
  AZURE_SUBSCRIPTION_ID  $SUB_ID
  TFSTATE_RESOURCE_GROUP $STATE_RG
  TFSTATE_STORAGE        $STATE_SA

Optional: ALERT_EMAIL     your email for alerts

Or set them all with the GitHub CLI:
  gh secret set AZURE_CLIENT_ID -b "$APP_ID" -R $REPO
  gh secret set AZURE_TENANT_ID -b "$TENANT_ID" -R $REPO
  gh secret set AZURE_SUBSCRIPTION_ID -b "$SUB_ID" -R $REPO
  gh secret set TFSTATE_RESOURCE_GROUP -b "$STATE_RG" -R $REPO
  gh secret set TFSTATE_STORAGE -b "$STATE_SA" -R $REPO
EOF
