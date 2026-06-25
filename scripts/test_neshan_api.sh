#!/usr/bin/env bash
# Test Neshan Geocoding Plus + Routing with GET (same as the Flutter app).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/secrets.local.sh" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT/secrets.local.sh"
fi

KEY="${NESHAN_API_KEY:-}"
if [[ -z "$KEY" ]]; then
  echo "NESHAN_API_KEY is empty. Copy secrets.local.sh.example to secrets.local.sh"
  exit 1
fi

echo "Key prefix: ${KEY:0:15}..."
echo ""
echo "=== Geocoding Plus (GET) ==="
GEO=$(curl -sS -w "\n__HTTP__%{http_code}" -G "https://api.neshan.org/geocoding/v1/plus" \
  --data-urlencode 'json={"address":"تهران","city":"تهران"}' \
  -H "Api-Key: $KEY")
GEO_BODY="${GEO%%__HTTP__*}"
GEO_CODE="${GEO##*__HTTP__}"
echo "HTTP: $GEO_CODE"
echo "$GEO_BODY" | head -c 400
echo ""
echo ""

echo "=== Place search (GET) ==="
SEARCH=$(curl -sS -w "\n__HTTP__%{http_code}" -G "https://api.neshan.org/v1/search" \
  --data-urlencode "term=میدان آزادی" \
  --data-urlencode "lat=35.6892" \
  --data-urlencode "lng=51.3890" \
  -H "Api-Key: $KEY")
SEARCH_BODY="${SEARCH%%__HTTP__*}"
SEARCH_CODE="${SEARCH##*__HTTP__}"
echo "HTTP: $SEARCH_CODE"
echo "$SEARCH_BODY" | head -c 400
echo ""
echo ""

echo "=== Routing with traffic (GET) ==="
ROUTE=$(curl -sS -w "\n__HTTP__%{http_code}" -G "https://api.neshan.org/v4/direction" \
  --data-urlencode "type=car" \
  --data-urlencode "origin=35.6892,51.3890" \
  --data-urlencode "destination=32.6539,51.6660" \
  --data-urlencode "alternative=true" \
  -H "Api-Key: $KEY")
ROUTE_BODY="${ROUTE%%__HTTP__*}"
ROUTE_CODE="${ROUTE##*__HTTP__}"
echo "HTTP: $ROUTE_CODE"
echo "$ROUTE_BODY" | head -c 400
echo ""

if [[ "$GEO_CODE" == "484" || "$ROUTE_CODE" == "484" || "$SEARCH_CODE" == "484" ]]; then
  echo ""
  echo "484 ApiWhiteListError: service keys must be called from whitelisted server IP/domain,"
  echo "or Android bundle must exactly match com.example.uzita in Neshan panel."
  echo "Recommended: deploy backend proxy (deploy/backend_neshan_proxy/) and whitelist"
  echo "device-control.liara.run on the service key."
fi
