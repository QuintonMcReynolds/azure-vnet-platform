# Runbook

## Deploy fails

| Symptom | Likely cause | Fix |
|---|---|---|
| `AuthorizationFailed` on role assignment | Deployer lacks RBAC rights | Re-run the role assignment section of `scripts/bootstrap.sh` |
| `MissingSubscriptionRegistration` | Resource provider not registered | `az provider register --namespace Microsoft.App --wait` (and the others in bootstrap) |
| `SubnetIsFull` or `NetcfgSubnetRangeOutsideVnet` | Subnet CIDR overlaps or sits outside the VNet | Pick free ranges inside the VNet's address space and update the tfvars |
| Key Vault `403 Forbidden` writing the secret | RBAC not propagated yet | Re-run; `time_sleep.rbac` waits 60s, but new tenants can be slower |
| Container app stuck `Provisioning` | Image pull or secret access failing | Check that the identity has `AcrPull` and `Key Vault Secrets User`, and the image tag exists |
| `/readyz` returns 503 | App can't reach Postgres | Check the private DNS zone link to the VNet, and the NSG rule for the app subnet on 5432 |
| PostgreSQL `region restricted` | SKU not offered in the region | Change `location` (for example `centralus`) or `db_sku` |

## Useful commands

```bash
RG=rg-notes-dev; APP=ca-notes-dev-api

az containerapp revision list -g $RG -n $APP -o table          # revisions and health
az containerapp logs show -g $RG -n $APP --follow              # live logs
az containerapp exec -g $RG -n $APP --command sh               # shell inside the container
az containerapp show -g $RG -n $APP --query properties.latestRevisionFqdn -o tsv
az acr repository show-tags -n <acr> --repository notes-api -o table
```

Log Analytics queries:

```kusto
ContainerAppConsoleLogs_CL
| where ContainerAppName_s == "ca-notes-dev-api"
| order by TimeGenerated desc

ContainerAppSystemLogs_CL
| where Reason_s in ("BackOff", "ProbeFailed", "ImagePullFailure")
| order by TimeGenerated desc
```

## Rollback

```bash
./scripts/rollback.sh dev <previous-git-sha>
```

The script checks that the tag exists in the registry, redeploys it, and runs the smoke test.

## Customer deployment checklist

Before deploying into a customer's VNet, confirm with their IT team:

1. Two free address ranges: a /27 or larger for the app, and a /28 for the database.
2. Permission to create subnets in their VNet, and to link a private DNS zone to it.
3. Whether outbound traffic goes through a firewall. If it does, allow Azure Container Registry,
   Microsoft Entra ID, and the Container Apps platform endpoints.
4. How their users will reach the app: VNet peering, VPN, or ExpressRoute, and which DNS server
   resolves the app's internal name.
5. A change window and a named contact for the cutover.
