#!/usr/bin/env bash
# Verify mission mabda/maghsad geocode to real metro areas (not Tehran city centre).
set -euo pipefail

API_BASE="${API_BASE_URL:-https://device-control.liara.run/api}"
USERNAME="${1:-drivertest}"
PASSWORD="${2:-}"

if [[ -z "$PASSWORD" ]]; then
  echo "Usage: $0 [username] [password]"
  exit 1
fi

login() {
  curl -sS -X POST "$API_BASE/login/" \
    -H 'Content-Type: application/json' \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}"
}

TOKEN=$(login | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")

geocode_no_bias() {
  local addr="$1"
  local json
  json=$(python3 -c "import json; print(json.dumps({'address': '''$addr''', 'city': 'تهران', 'province': 'تهران'}, ensure_ascii=False))")
  curl -sS -G "$API_BASE/transport/neshan/geocode" \
    --data-urlencode "json=$json" \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Accept: application/json'
}

check_not_city_centre() {
  local label="$1"
  local lat="$2"
  local lng="$3"
  python3 - "$label" "$lat" "$lng" <<'PY'
import math, sys
label, lat, lng = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
cent_lat, cent_lng = 35.6892, 51.3890
dlat = (lat - cent_lat) * 111000
dlng = (lng - cent_lng) * 111000 * math.cos(math.radians(cent_lat))
dist = math.hypot(dlat, dlng)
print(f"{label}: {lat:.4f}, {lng:.4f} — {dist/1000:.1f} km from city centre")
if dist < 2800:
    print(f"FAIL: {label} snapped to city centre cluster")
    sys.exit(1)
PY
}

MABDA='تهران، ایستگاه مترو میدان فردوسی'
MAGHSA='تهران ، ایستگاه مترو باقری'

echo "=== Mission geocode verification ==="
for pair in "mabda|$MABDA" "maghsad|$MAGHSA"; do
  label="${pair%%|*}"
  addr="${pair#*|}"
  body=$(geocode_no_bias "$addr")
  read -r lat lng < <(python3 -c "import json,sys; d=json.load(sys.stdin); i=d['items'][0]['location']; print(i['latitude'], i['longitude'])" <<<"$body")
  check_not_city_centre "$label" "$lat" "$lng"
done

echo "OK: both endpoints resolve outside the city-centre snap cluster"
