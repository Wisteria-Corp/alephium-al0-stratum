#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "Missing .env — run ./scripts/init-config.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

if [[ -z "${ALEPHIUM_API_KEY:-}" ]]; then
  echo "ALEPHIUM_API_KEY is empty." >&2
  exit 1
fi

HOST="${NODE_REST:-http://127.0.0.1:12973}"
json="$(curl -fsS -H "X-API-KEY: ${ALEPHIUM_API_KEY}" "${HOST}/infos/self-clique")"
echo "$json"

py=""
if command -v python3 >/dev/null 2>&1; then
  py=python3
elif command -v python >/dev/null 2>&1; then
  py=python
fi

if [[ -n "$py" ]]; then
  printf '%s' "$json" | "$py" -c "import json,sys; data=json.load(sys.stdin); r,s=data.get('selfReady'), data.get('synced'); print('selfReady:', r); print('synced:', s); sys.exit(0 if r is True and s is True else 2)"
else
  echo "$json" | grep -Eq '"selfReady"[[:space:]]*:[[:space:]]*true' \
    && echo "$json" | grep -Eq '"synced"[[:space:]]*:[[:space:]]*true'
fi
