#!/usr/bin/env bash
set -euo pipefail

MESH_COMPUTE_URL="${MESH_COMPUTE_URL:-http://samuel-mbp:11434/v1}"
BASE_URL="${MESH_COMPUTE_URL%/}"
MODELS_URL="${BASE_URL}/models"

echo "checking mesh compute endpoint: ${MODELS_URL}"

if ! RESPONSE="$(curl -fsS --connect-timeout 10 --max-time 30 "${MODELS_URL}")"; then
  echo "error: failed to reach ${MODELS_URL}" >&2
  echo "hint: set MESH_COMPUTE_URL (e.g. http://100.100.119.4:11434/v1 or http://samuel-mbp:11434/v1)" >&2
  exit 1
fi

if ! echo "${RESPONSE}" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
  echo "error: response is not valid JSON" >&2
  echo "${RESPONSE}" >&2
  exit 1
fi

echo "ok: /v1/models reachable"
echo ""
echo "models summary:"
echo "${RESPONSE}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
models = data.get('data', data if isinstance(data, list) else [])
if not models:
    print('  (no models listed)')
    sys.exit(0)
for m in models:
    if isinstance(m, dict):
        mid = m.get('id', m.get('name', str(m)))
        print(f'  - {mid}')
    else:
        print(f'  - {m}')
print(f'total: {len(models)} model(s)')
"
