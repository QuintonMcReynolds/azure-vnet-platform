#!/usr/bin/env bash
# Post-deploy check. Public deployments: hit the API over HTTPS.
# Internal (VNet-only) deployments: confirm the new revision is running and healthy via the Azure API,
# since a GitHub-hosted runner is outside the customer network.
set -euo pipefail

RG="${1:?resource group}"
APP="${2:?container app name}"
URL="${3:-}"
INTERNAL="${4:-false}"
EXPECTED_VERSION="${5:-}"

wait_for_revision() {
  for i in $(seq 1 30); do
    state="$(az containerapp revision list -g "$RG" -n "$APP" \
      --query "[?properties.active].{h:properties.healthState,r:properties.runningState}" -o tsv | head -1)"
    echo "attempt $i: revision state = ${state:-unknown}"
    if [[ "$state" == Healthy* ]]; then return 0; fi
    sleep 10
  done
  return 1
}

wait_for_revision || { echo "Revision never became healthy"; exit 1; }

if [[ "$INTERNAL" == "true" || -z "$URL" ]]; then
  echo "Internal deployment: revision is healthy. Skipping HTTP checks from outside the VNet."
  exit 0
fi

for i in $(seq 1 20); do
  if curl -fsS "$URL/readyz" >/dev/null; then break; fi
  echo "waiting for $URL/readyz ($i)"; sleep 6
done

curl -fsS "$URL/healthz"; echo
curl -fsS "$URL/readyz"; echo
info="$(curl -fsS "$URL/")"; echo "$info"
curl -fsS -X POST "$URL/api/notes" -H 'content-type: application/json' -d '{"text":"smoke test"}' >/dev/null
curl -fsS "$URL/api/notes?limit=1" | grep -q "smoke test"

if [[ -n "$EXPECTED_VERSION" ]] && ! grep -q "$EXPECTED_VERSION" <<<"$info"; then
  echo "Wrong version is live (expected $EXPECTED_VERSION)"; exit 1
fi
echo "Smoke test passed."
