#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example"
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

if [[ -z "${ALEPHIUM_API_KEY:-}" ]]; then
  ALEPHIUM_API_KEY="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 48)"
  if grep -q '^ALEPHIUM_API_KEY=' .env; then
    tmp="$(mktemp)"
    awk -v k="$ALEPHIUM_API_KEY" 'BEGIN{done=0} /^ALEPHIUM_API_KEY=/{print "ALEPHIUM_API_KEY=" k; done=1; next} {print} END{if(!done) print "ALEPHIUM_API_KEY=" k}' .env >"$tmp"
    mv "$tmp" .env
  else
    printf '\nALEPHIUM_API_KEY=%s\n' "$ALEPHIUM_API_KEY" >>.env
  fi
  echo "Generated ALEPHIUM_API_KEY (>= 32 chars) in .env"
fi

missing=0
for var in MINER_ADDRESS_G0 MINER_ADDRESS_G1 MINER_ADDRESS_G2 MINER_ADDRESS_G3; do
  if [[ -z "${!var:-}" ]]; then
    echo "Fill $var in .env (one mainnet address per group)." >&2
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

mkdir -p config
sed \
  -e "s/REPLACE_WITH_API_KEY_MIN_32_CHARS/${ALEPHIUM_API_KEY}/g" \
  -e "s/REPLACE_MINER_ADDRESS_G0/${MINER_ADDRESS_G0}/g" \
  -e "s/REPLACE_MINER_ADDRESS_G1/${MINER_ADDRESS_G1}/g" \
  -e "s/REPLACE_MINER_ADDRESS_G2/${MINER_ADDRESS_G2}/g" \
  -e "s/REPLACE_MINER_ADDRESS_G3/${MINER_ADDRESS_G3}/g" \
  config/user.conf.example >config/user.conf

sed \
  -e "s/REPLACE_WITH_API_KEY_MIN_32_CHARS/${ALEPHIUM_API_KEY}/g" \
  -e "s/REPLACE_MINER_ADDRESS_G0/${MINER_ADDRESS_G0}/g" \
  -e "s/REPLACE_MINER_ADDRESS_G1/${MINER_ADDRESS_G1}/g" \
  -e "s/REPLACE_MINER_ADDRESS_G2/${MINER_ADDRESS_G2}/g" \
  -e "s/REPLACE_MINER_ADDRESS_G3/${MINER_ADDRESS_G3}/g" \
  config/pool.json.example >config/pool.json

echo "Wrote config/user.conf and config/pool.json"
echo "These files are gitignored. Do not commit them."
