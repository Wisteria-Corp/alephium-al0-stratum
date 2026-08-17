#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA="$ROOT/data/alephium"
mkdir -p "$DATA"

NETWORK="${ALEPHIUM_NETWORK:-mainnet}"
NODE_TYPE="${NODE_TYPE:-pruned}"
# Pruned snapshots always ship without indexes.
INDEXES_CONFIG="${INDEXES_CONFIG:-without-indexes}"
LIST_URL="https://archives.alephium.org/archives/${NETWORK}/${NODE_TYPE}-node-data/_latest_${INDEXES_CONFIG}.txt"

echo "Resolving latest snapshot URL from ${LIST_URL}"
SNAP_URL="$(curl -fsSL --http1.1 "$LIST_URL")"
echo "Snapshot: ${SNAP_URL}"

TAR="$DATA/_snapshot.tar"
attempt=0
until curl --http1.1 -fL -C - -o "$TAR" "$SNAP_URL"; do
  attempt=$((attempt + 1))
  echo "Download interrupted (attempt ${attempt}). Resuming in 5s…" >&2
  sleep 5
done

echo "Extracting into ${DATA}"
tar xf "$TAR" -C "$DATA"

if [[ "$(id -u)" -eq 0 ]]; then
  chown -R 65534:65534 "$DATA"
  echo "Ownership set to 65534:65534 (container user nobody)."
else
  echo "If the node cannot read data or user.conf, run:"
  echo "  sudo chown -R 65534:65534 \"$DATA\""
fi

echo "Keep the tar until the node reports synced: true, then delete it to reclaim disk:"
echo "  rm -f \"$TAR\""
