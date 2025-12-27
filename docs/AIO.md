# All-in-One (AIO) Deployment Guide

## Overview

The AIO image bundles all components into a single Docker container:

**Payment Processing:**
- BTCPay Server (multi-crypto payment processor)
- NBXplorer (blockchain indexer)
- PostgreSQL (database)

**Blockchain Nodes:**
- Bitcoin Core (full node)
- Monero Daemon (full node)

**Block Explorer:**
- Mempool.space (self-hosted Bitcoin explorer)

## Architecture

The AIO image uses a **dual-volume architecture** designed for production deployments:

```
┌─────────────────────────────────────────────────────────────────┐
│                        AIO Container                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   /config (NVMe RAID 1)          /chaindata (HDD)               │
│   ━━━━━━━━━━━━━━━━━━━━           ━━━━━━━━━━━━━━━━               │
│   CRITICAL - BACKED UP           EXPENDABLE - NOT BACKED UP     │
│                                                                 │
│   ├── postgres/                  ├── btc/                       │
│   ├── btcpay/                    │   └── blocks/                │
│   ├── btcpay-plugins/            │   └── chainstate/            │
│   ├── nbxplorer/                 │                              │
│   ├── btc/                       ├── xmr/                       │
│   │   └── bitcoin.conf           │   └── lmdb/                  │
│   ├── xmr/                       │                              │
│   │   └── monero.conf            └── mempool/                   │
│   ├── mempool/                       └── cache/                 │
│   ├── backups/                                                  │
│   └── .credentials                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Why Dual Volumes?

| Volume | Storage Type | Purpose | Backup |
|--------|--------------|---------|--------|
| `/config` | NVMe RAID 1 (1TB) | Critical data: wallets, configs, database | **Yes** |
| `/chaindata` | HDD (10TB) | Blockchain data: can be re-synced | **No** |

**Key insight:** Blockchain data is publicly available and can be re-downloaded. If `/chaindata` is lost, the node simply re-syncs from the network. This allows using cheaper, non-redundant storage for the ~1TB of chain data.

## Quick Start

```bash
# Create volumes
docker volume create btcpay-config
docker volume create btcpay-chaindata

# Run with dual volumes
docker run -d \
  --name btcpay \
  -p 443:443 \
  -p 8080:8080 \
  -v btcpay-config:/config \
  -v btcpay-chaindata:/chaindata \
  -e DOMAIN=pay.example.com \
  -e BTCPAY_PROTOCOL=https \
  ghcr.io/host-uk/docker-server-blockchain-aio:latest
```

## Configuration

### Environment Variables

#### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | `localhost` | External hostname for all services |
| `BTCPAY_NETWORK` | `mainnet` | Network: mainnet, testnet, regtest, signet |
| `BTCPAY_PROTOCOL` | `https` | External protocol (http, https) |
| `BTCPAY_ROOTPATH` | `/` | URL root path |

#### Bitcoin Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `BITCOIN_RPC_USER` | `btcpayrpc` | Bitcoin RPC username |
| `BITCOIN_RPC_PASSWORD` | (generated) | Bitcoin RPC password |
| `BITCOIN_RPC_PORT` | `8332` | Bitcoin RPC port |
| `BITCOIN_PRUNE` | `0` | Prune MB (0 = full node) |
| `BITCOIN_DBCACHE` | `512` | Database cache MB |
| `BITCOIN_MAXMEMPOOL` | `300` | Max mempool MB |

#### Monero Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `MONERO_RPC_USER` | `monerorpc` | Monero RPC username |
| `MONERO_RPC_PASSWORD` | (generated) | Monero RPC password |
| `XMR_RPC_PORT` | `18081` | Monero RPC port |
| `XMR_P2P_PORT` | `18080` | Monero P2P port |
| `XMR_ZMQ_PORT` | `18082` | Monero ZMQ port |

#### Database Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | `btcpay` | PostgreSQL username |
| `POSTGRES_PASSWORD` | (generated) | PostgreSQL password |

#### Backup Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKUP_DIR` | `/config/backups` | Backup destination |
| `BACKUP_RETENTION_DAYS` | `30` | Days to keep backups |

### Volume Structure

#### /config (Critical - Backed Up)

```
/config
├── postgres/           # PostgreSQL database (wallets, invoices, users)
├── btcpay/             # BTCPay Server settings
├── btcpay-plugins/     # Installed plugins
├── nbxplorer/          # NBXplorer configuration
├── btc/                # Bitcoin configuration (bitcoin.conf)
├── xmr/                # Monero configuration (monero.conf)
├── mempool/            # Mempool configuration
├── backups/            # Automated backups
└── .credentials        # Generated credentials
```

#### /chaindata (Expendable - Not Backed Up)

```
/chaindata
├── btc/                # Bitcoin blockchain (~700GB mainnet)
│   ├── blocks/
│   └── chainstate/
├── xmr/                # Monero blockchain (~200GB mainnet)
│   └── lmdb/
└── mempool/            # Mempool cache and indexes
    └── cache/
```

## Production Deployment

### Recommended Storage Setup

```bash
# Example: NVMe RAID 1 for config, single HDD for chaindata
# Assuming:
#   /dev/md0 = NVMe RAID 1 mounted at /mnt/nvme
#   /dev/sda = 10TB HDD mounted at /mnt/hdd

# Create directories
mkdir -p /mnt/nvme/btcpay
mkdir -p /mnt/hdd/btcpay

# Run container
docker run -d \
  --name btcpay \
  --restart unless-stopped \
  -p 443:443 \
  -p 8080:8080 \
  -p 8333:8333 \
  -p 18080:18080 \
  -v /mnt/nvme/btcpay:/config \
  -v /mnt/hdd/btcpay:/chaindata \
  -e DOMAIN=pay.example.com \
  -e BTCPAY_PROTOCOL=https \
  -e BTCPAY_NETWORK=mainnet \
  -e BITCOIN_DBCACHE=2048 \
  ghcr.io/host-uk/docker-server-blockchain-aio:latest
```

### Docker Compose

```yaml
version: '3.8'

services:
  btcpay:
    image: ghcr.io/host-uk/docker-server-blockchain-aio:latest
    container_name: btcpay
    restart: unless-stopped
    ports:
      - "443:443"       # BTCPay Server (HTTPS)
      - "8080:8080"     # Mempool Explorer
      - "8333:8333"     # Bitcoin P2P (optional)
      - "18080:18080"   # Monero P2P (optional)
    volumes:
      # Critical data - NVMe RAID 1
      - /mnt/nvme/btcpay:/config
      # Expendable chain data - HDD
      - /mnt/hdd/btcpay:/chaindata
    environment:
      - DOMAIN=pay.example.com
      - BTCPAY_PROTOCOL=https
      - BTCPAY_NETWORK=mainnet
      - BITCOIN_DBCACHE=2048
      - BITCOIN_PRUNE=0
    healthcheck:
      test: ["CMD", "/scripts/health-check.sh"]
      interval: 60s
      timeout: 30s
      retries: 3
```

### State Directory Structure

For the recommended `./state/pay.host.uk.com/` layout:

```bash
# Create state directories
mkdir -p ./state/pay.host.uk.com/config
mkdir -p ./state/pay.host.uk.com/chaindata

# Run with state directories
docker run -d \
  --name btcpay \
  -p 443:443 \
  -p 8080:8080 \
  -v $(pwd)/state/pay.host.uk.com/config:/config \
  -v $(pwd)/state/pay.host.uk.com/chaindata:/chaindata \
  -e DOMAIN=pay.host.uk.com \
  ghcr.io/host-uk/docker-server-blockchain-aio:latest
```

## Services and Ports

| Port | Service | Description | Expose |
|------|---------|-------------|--------|
| 443 | BTCPay Server | Payment processor web UI | **Yes** |
| 8080 | Mempool | Block explorer web UI | **Yes** |
| 8999 | Mempool API | Block explorer backend | No |
| 32838 | NBXplorer | Blockchain indexer | No |
| 8332 | Bitcoin RPC | Bitcoin node RPC | No |
| 8333 | Bitcoin P2P | Bitcoin network | Optional |
| 18080 | Monero P2P | Monero network | Optional |
| 18081 | Monero RPC | Monero node RPC | No |
| 5432 | PostgreSQL | Database | No |

## Monitoring

### Health Check

```bash
# Container health
docker exec btcpay /scripts/health-check.sh

# Service status
docker exec btcpay supervisorctl status
```

Expected output when healthy:
```
bitcoind                         RUNNING   pid 123, uptime 1:23:45
btcpayserver                     RUNNING   pid 456, uptime 1:23:45
mempool                          RUNNING   pid 789, uptime 1:23:45
monerod                          RUNNING   pid 234, uptime 1:23:45
nbxplorer                        RUNNING   pid 567, uptime 1:23:45
nginx                            RUNNING   pid 890, uptime 1:23:45
postgres                         RUNNING   pid 111, uptime 1:23:45
```

### Blockchain Sync Status

```bash
# Bitcoin sync progress
docker exec btcpay bitcoin-cli \
  -rpcuser=btcpayrpc \
  -rpcpassword=$(docker exec btcpay cat /config/.credentials | grep BITCOIN_RPC_PASSWORD | cut -d= -f2) \
  getblockchaininfo | jq '.verificationprogress'

# Monero sync progress
docker exec btcpay curl -s \
  -u monerorpc:$(docker exec btcpay cat /config/.credentials | grep MONERO_RPC_PASSWORD | cut -d= -f2) \
  http://127.0.0.1:18081/json_rpc \
  -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' \
  -H 'Content-Type: application/json' | jq '.result.synchronized'
```

### Logs

```bash
# All logs
docker logs -f btcpay

# Specific service logs
docker exec btcpay cat /var/log/supervisor/btcpayserver.log
docker exec btcpay cat /var/log/supervisor/bitcoind.log
docker exec btcpay cat /var/log/supervisor/monerod.log
docker exec btcpay cat /var/log/supervisor/mempool.log
```

## Backup and Restore

### Understanding What to Backup

**BACKUP (`/config`):**
- PostgreSQL database (wallets, invoices, users, settings)
- BTCPay Server configuration and plugins
- Node configuration files
- Credentials

**DO NOT BACKUP (`/chaindata`):**
- Bitcoin blockchain (~700GB) - re-sync from network
- Monero blockchain (~200GB) - re-sync from network
- Mempool indexes - rebuilt automatically

### Automated Backup

```bash
# Run backup (only backs up /config)
docker exec btcpay /scripts/backup.sh

# List backups
docker exec btcpay /scripts/backup.sh --list

# Verify latest backup
docker exec btcpay /scripts/backup.sh --verify

# Custom backup location
docker exec btcpay /scripts/backup.sh -d /config/backups -r 14
```

### Manual Backup

```bash
# Stop for consistent backup (optional but recommended)
docker stop btcpay

# Backup only /config (critical data)
tar -czf btcpay-config-$(date +%Y%m%d).tar.gz /mnt/nvme/btcpay

# DO NOT backup /chaindata - it's ~1TB of re-downloadable data
# tar -czf btcpay-chaindata.tar.gz /mnt/hdd/btcpay  # DON'T DO THIS

docker start btcpay
```

### Restore

```bash
# 1. Stop container
docker stop btcpay

# 2. Restore config (critical data)
tar -xzf btcpay-config-20240101.tar.gz -C /mnt/nvme/

# 3. Ensure chaindata directory exists (can be empty)
mkdir -p /mnt/hdd/btcpay

# 4. Start container - blockchains will re-sync automatically
docker start btcpay

# 5. Monitor sync progress
docker exec btcpay /scripts/health-check.sh
```

### Disaster Recovery

If `/chaindata` is lost (HDD failure, corruption):

```bash
# 1. Replace/format HDD
mkfs.ext4 /dev/sda
mount /dev/sda /mnt/hdd

# 2. Create chaindata directory
mkdir -p /mnt/hdd/btcpay

# 3. Restart container - automatic resync
docker restart btcpay

# 4. Initial sync takes time:
#    - Bitcoin: ~2-7 days depending on hardware
#    - Monero: ~1-3 days depending on hardware
```

## Resource Requirements

### Minimum (Production)

- **CPU:** 4 cores
- **RAM:** 8GB
- **Storage (config):** 50GB NVMe/SSD
- **Storage (chaindata):** 1TB HDD

### Recommended (Production)

- **CPU:** 8 cores
- **RAM:** 16GB
- **Storage (config):** 100GB NVMe RAID 1
- **Storage (chaindata):** 2TB HDD

### Initial Sync Requirements

During initial blockchain synchronization:
- **Bitcoin:** ~700GB download, 2-7 days
- **Monero:** ~200GB download, 1-3 days
- **Mempool:** Indexes built after Bitcoin syncs

Higher `BITCOIN_DBCACHE` (e.g., 4096) significantly speeds up initial sync.

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs btcpay

# Verify volume permissions
ls -la /mnt/nvme/btcpay
ls -la /mnt/hdd/btcpay

# Check disk space
df -h /mnt/nvme /mnt/hdd
```

### Services Not Starting

```bash
# Check supervisor status
docker exec btcpay supervisorctl status

# Restart specific service
docker exec btcpay supervisorctl restart bitcoind
docker exec btcpay supervisorctl restart monerod

# Check service logs
docker exec btcpay tail -100 /var/log/supervisor/bitcoind.log
```

### Database Issues

```bash
# Check PostgreSQL
docker exec btcpay pg_isready -U btcpay
docker exec btcpay psql -U btcpay -c "SELECT 1"

# Repair PostgreSQL (if corrupted)
docker exec btcpay su-exec postgres pg_resetwal /config/postgres
```

### Slow Sync

```bash
# Increase Bitcoin cache (requires restart)
docker exec btcpay supervisorctl stop bitcoind
# Edit /config/btc/bitcoin.conf: dbcache=4096
docker exec btcpay supervisorctl start bitcoind
```

### Out of Disk Space

```bash
# Check usage
docker exec btcpay du -sh /config/* /chaindata/*

# If chaindata is full, consider:
# 1. Larger HDD
# 2. Pruning Bitcoin (set BITCOIN_PRUNE=550)
```

## Coolify Deployment

1. Add new service → Docker Image
2. Image: `ghcr.io/host-uk/docker-server-blockchain-aio:latest`
3. Configure two volume mounts:
   - `/config` → Persistent storage (fast, redundant)
   - `/chaindata` → Persistent storage (large, can be non-redundant)
4. Set environment variables:
   - `DOMAIN`: `{{SERVICE_FQDN_BTCPAYSERVER}}`
   - `BTCPAY_PROTOCOL`: `https`
5. Expose ports: `443`, `8080`

## Security Considerations

1. **Credentials:** Auto-generated and stored in `/config/.credentials`
2. **RPC Access:** Internal only by default (not exposed)
3. **HTTPS:** Use reverse proxy (Traefik, Caddy) for SSL termination
4. **Backups:** Store encrypted backups off-site
5. **Updates:** Regularly pull latest image for security patches

## Support

- **Issues:** https://github.com/host-uk/docker-server-blockchain/issues
- **Documentation:** https://docs.btcpayserver.org
- **BTCPay Server:** https://btcpayserver.org
