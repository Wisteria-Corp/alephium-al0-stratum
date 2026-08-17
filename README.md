# IceRiver AL0 → Stratum → Alephium full node

Home-lab kit for **IceRiver AL0** (and other Stratum-only ASICs) on a **private** Alephium node.

GPU miners talk to the node's Mining API on `:10973` (Alephium's own TCP protocol). **AL0 does not.** Its pool field is `stratum+tcp://…`. Pointing an AL0 at `:10973` will not work. This repo puts the official [`alephium/mining-pool`](https://github.com/alephium/mining-pool) in between, as a **single-owner Stratum gateway** on `:20032`.

```text
IceRiver AL0
  └─ stratum+tcp://<LAN host>:20032
       └─ alephium/mining-pool  (rewardEnabled: false)
            ├─ full node REST      :12973  (localhost only)
            ├─ full node Miner API :10973  (docker network only)
            └─ Redis               :6379   (docker network only)
```

This is not a public pool. Do not publish `:20032` to the internet.

## What this is / is not

**Is**

- A reproducible Docker Compose stack: node `v4.6.0` + mining-pool commit `80d252e` + Redis
- A correction of guides that send AL0 to `:10973`
- LAN-only solo: the node coinbase addresses receive block rewards; the pool does not hold a wallet or pay miners

**Is not**

- A profitability product. Hashprice moves. Run the numbers before you leave hardware on.
- A hosted pool, tax guide, or cloud deployment
- A reason to expose REST, Miner API, Redis, or Stratum beyond your LAN

## Requirements

- Docker Engine + Compose
- Disk: a **pruned** mainnet snapshot is the practical path (see [Load from a snapshot](https://docs.alephium.org/full-node/loading-snapshot)). Budget well over 200 GB free (snapshot + extract + headroom). A full snapshot is larger.
- Four **mainnet** addresses, **one per group** (0–3). Rewards land on the node's `miner-addresses`, not on the ASIC worker name.
- IceRiver AL0 (or any miner that only speaks Stratum)

Check an address group without your node:

```bash
curl -sS "https://backend.mainnet.alephium.org/addresses/<ADDRESS>/group"
```

## Quick start

```bash
cp .env.example .env
# edit .env: API key (or leave blank for auto-generate) and four miner addresses
./scripts/init-config.sh
./scripts/load-pruned-snapshot.sh   # skip if you already have node data
docker compose up -d --build
./scripts/check-synced.sh           # wait until selfReady + synced
```

Then point **one** AL0 at the gateway. Leave a commercial pool on Pool 2 / Pool 3 if you want failover.

| AL0 field | Value |
|---|---|
| Pool 1 URL | `stratum+tcp://<LAN_IP_OF_DOCKER_HOST>:20032` |
| Wallet / Worker | `<GROUP0_ADDRESS>.rig01` |
| Password | empty |

The worker suffix (`.rig01`) is an identifier only. It is not a payout account.

Do not save the AL0 form until `check-synced.sh` prints `synced: true`. The pool will not serve jobs while the Miner API is still catching up.

## Verify

On the host:

```bash
docker compose logs -f mining-pool
```

You want `Received share` (or equivalent) for the worker name you set. Node, pool, and Redis should stay `healthy`.

A share is not a block. This kit has been used to accept AL0 shares against a synced `v4.6.0` node; finding a block is luck and network difficulty.

## Security

- Publish **P2P** `:9973/tcp` and `:9973/udp` so the node can sync. That is the only port that should face the public internet.
- Bind REST to `127.0.0.1:12973`. Swagger: `http://127.0.0.1:12973/docs` with header `X-API-KEY`.
- Do **not** publish `:10973`, `:6379`, or Postgres. This compose file does not run Postgres.
- Firewall `:20032/tcp` to the miner subnet only. If several ASICs share one source IP (a proxy), raise `maxConnectionsFromSameIP` in `config/pool.json` (default in this kit is 32).
- `rewardEnabled` / `paymentEnabled` are **false**. Leave `wallet` empty. Never put a mnemonic in the pool config.
- Upstream mining-pool still builds on **Node.js 16**. Treat it as LAN software. Rebuild from the pinned commit; do not `npm audit fix` blindly and assume protocol compatibility.

## Pins (validated)

| Piece | Pin | Why |
|---|---|---|
| Node image | `alephium/alephium:v4.6.0` | Synced mainnet node + AL0 shares accepted (2026-08-02) |
| mining-pool | `80d252e6fcb5b1182a69b5fb4f06f9f5806f1144` (current `master`) | Same commit; Mining Protocol v1 |
| Stratum | `:20032` | Official single-user example |
| Solo diff | `diff: 8`, `minDiff: 1` | Official single-user example; AL0 submitted shares above that floor |

If you bump the node image, re-verify the pool against the Miner API before pointing ASICs at it. Official mining-pool GitHub Releases lag `master`.

## Snapshot download

The docs pipe `curl \| tar` in one shot. Long pruned archives can fail mid-stream (`HTTP/2 INTERNAL_ERROR`, then `tar: Unexpected EOF`). `scripts/load-pruned-snapshot.sh` instead:

1. Resolves the latest pruned URL from [archives.alephium.org](https://archives.alephium.org)
2. Downloads with **HTTP/1.1** and **resume** (`curl --http1.1 -C -`)
3. Extracts into `./data/alephium`
4. Reminds you to `chown -R 65534:65534 data/alephium` (container user `nobody`)

After the node is `synced: true`, delete the tar to reclaim disk.

## Economics (not advice)

AL0 published figures are on the order of **400 GH/s** at about **100 W**. At a placeholder residential rate of **$0.18/kWh**, one unit costs about **$0.43/day** in electricity before cooling.

Revenue is `accepted_hashes × block_reward × ALPH_price`, after difficulty. In **August 2026** ALPH was around **$0.027**; one AL0 on a ~5 PH/s network was **not** covering that power cost. Re-run with today's price and hashrate. If the unit is already off, leaving it off is a valid decision.

## Common mistakes

1. **AL0 → `stratum+tcp://127.0.0.1:10973`** — wrong protocol. `:10973` is not Stratum.
2. **One address copied four times** — Alephium needs four groups. Coinbase will be wrong or mining will not start.
3. **Exposing `:20032` on a VPS** — you then run a public pool with unaudited Node 16. Don't.
4. **Putting the mnemonic in `pool.json`** — unnecessary for this solo layout.

## License

MIT. Alephium node and mining-pool remain under their upstream licenses.
