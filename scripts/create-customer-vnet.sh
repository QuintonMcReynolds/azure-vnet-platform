#!/usr/bin/env bash
# Simulates a customer's existing network so you can practice deploying into it.
# This plays the role of the customer IT team: they own the VNet, you get to add subnets.
set -euo pipefail

LOCATION="${1:-eastus2}"
RG="rg-contoso-network"
VNET="vnet-contoso-corp"

az group create -n "$RG" -l "$LOCATION" --tags owner=customer-it -o none
az network vnet create -g "$RG" -n "$VNET" -l "$LOCATION" \
  --address-prefixes 10.60.0.0/16 \
  --subnet-name snet-corp-workloads --subnet-prefixes 10.60.0.0/24 -o none

# A small VM-free "jumpbox" subnet is a common customer pattern; reserved here for docs/examples.
az network vnet subnet create -g "$RG" --vnet-name "$VNET" -n snet-corp-jumpbox \
  --address-prefixes 10.60.1.0/27 -o none

echo "Customer VNet ready: $VNET (10.60.0.0/16) in $RG"
echo "Free ranges for the vendor app: 10.60.10.0/27 (app) and 10.60.11.0/28 (database)."
