# All-in-One (AIO) Deployment Guide

## Overview

The AIO image bundles all BTCPay Server components into a single Docker container:
- BTCPay Server (payment processor)
- NBXplorer (blockchain indexer)
- Bitcoin Core (full/pruned node)
- PostgreSQL (database)

This simplifies deployment, especially when mounting storage from NAS or shared volumes.

## Quick Start

```bash
# Pull the image
docker pull ghcr.io/host-uk/docker-server-blockchain-aio:latest

# Run with minimal configuration
docker run -d \
  --name btcpay \
  -p 80:49392 \
  -v btcpay-data:/data \
  -e BTCPAY_HOST=your.domain.com \
  -e BTCPAY_PROTOCOL=https \
  ghcr.io/host-uk/docker-server-blockchain-aio:latest
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BTCPAY_NETWORK` | `mainnet` | Bitcoin network (mainnet, testnet, regtest, signet) |
| `BTCPAY_HOST` | `localhost` | External hostname |
| `BTCPAY_PROTOCOL` | `http` | External protocol (http, https) |
| `BTCPAY_ROOTPATH` | `/` | URL root path |
| `BITCOIN_PRUNE` | `550` | Prune blockchain (MB). Set to 0 for full node |
| `BITCOIN_DBCACHE` | `512` | Database cache size (MB) |
| `BITCOIN_MAXMEMPOOL` | `300` | Max mempool size (MB) |
| `POSTGRES_USER` | `btcpay` | PostgreSQL username |
| `POSTGRES_PASSWORD` | (generated) | PostgreSQL password |
| `BITCOIN_RPC_USER` | `btcpayrpc` | Bitcoin RPC username |
| `BITCOIN_RPC_PASSWORD` | (generated) | Bitcoin RPC password |

### Volume Structure

All persistent data is stored under `/data`:

```
/data
├── bitcoin/           # Bitcoin blockchain data
├── bitcoin-wallet/    # Bitcoin wallet files
├── postgres/          # PostgreSQL database
├── nbxplorer/         # NBXplorer data
├── btcpay/            # BTCPay Server data
└── btcpay-plugins/    # BTCPay plugins
```

## Deployment Examples

### Basic Deployment

```bash
docker run -d \
  --name btcpay \
  -p 443:49392 \
  -v /mnt/nas/btcpay:/data \
  -e BTCPAY_HOST=btcpay.example.com \
  -e BTCPAY_PROTOCOL=https \
  -e BTCPAY_NETWORK=mainnet \
  -e BITCOIN_PRUNE=550 \
  ghcr.io/host-uk/docker-server-blockchain-aio:latest
```

### Full Node (No Pruning)

```bash
docker run -d \
  --name btcpay \
  -p 443:49392 \
  -v /mnt/fast-storage/btcpay:/data \
  -e BTCPAY_HOST=btcpay.example.com \
  -e BTCPAY_PROTOCOL=https \
  -e BITCOIN_PRUNE=0 \
  -e BITCOIN_DBCACHE=2048 \
  ghcr.io/host-uk/docker-server-blockchain-aio:latest
```

### Testnet Deployment

```bash
docker run -d \
  --name btcpay-testnet \
  -p 8080:49392 \
  -v btcpay-testnet:/data \
  -e BTCPAY_HOST=testnet.example.com \
  -e BTCPAY_NETWORK=testnet \
  ghcr.io/host-uk/docker-server-blockchain-aio:latest
```

## Coolify Deployment

For Coolify, use the AIO image directly:

1. Add new service → Docker Image
2. Image: `ghcr.io/host-uk/docker-server-blockchain-aio:latest`
3. Set environment variables:
   - `BTCPAY_HOST`: Use `{{SERVICE_FQDN_BTCPAYSERVER}}`
   - `BTCPAY_PROTOCOL`: `https`
   - `BTCPAY_NETWORK`: `mainnet`
4. Configure volume mount to persistent storage
5. Set exposed port to `49392`

## NAS Storage

The AIO image is designed for NAS-backed storage:

```bash
# Mount NFS share
mount -t nfs nas.local:/btcpay /mnt/btcpay

# Run with NAS storage
docker run -d \
  --name btcpay \
  -p 443:49392 \
  -v /mnt/btcpay:/data \
  -e BTCPAY_HOST=btcpay.example.com \
  -e BTCPAY_PROTOCOL=https \
  ghcr.io/host-uk/docker-server-blockchain-aio:latest
```

### Storage Considerations

| Storage Type | Recommendation |
|--------------|----------------|
| SSD/NVMe | Best for full nodes and high-traffic stores |
| HDD | Acceptable for pruned nodes |
| NAS (NFS) | Good for backups and multi-server |
| NAS (iSCSI) | Better performance than NFS |

## Monitoring

### Health Check

The container exposes a health endpoint:

```bash
curl http://localhost:49392/health
```

### Service Status

```bash
docker exec btcpay supervisorctl status
```

### Logs

```bash
# All logs
docker logs btcpay

# Specific service logs
docker exec btcpay cat /var/log/supervisor/btcpayserver.log
docker exec btcpay cat /var/log/supervisor/bitcoind.log
```

## Backup

```bash
# Stop container
docker stop btcpay

# Backup entire data directory
tar -czf btcpay-backup-$(date +%Y%m%d).tar.gz /path/to/data

# Restart
docker start btcpay
```

For hot backups, see `scripts/backup.sh`.

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs btcpay

# Check if port is in use
netstat -tlnp | grep 49392
```

### Services Not Starting

```bash
# Check supervisor status
docker exec btcpay supervisorctl status

# Check individual service logs
docker exec btcpay cat /var/log/supervisor/postgres.log
docker exec btcpay cat /var/log/supervisor/bitcoind.log
```

### Database Connection Issues

```bash
# Check PostgreSQL
docker exec btcpay pg_isready -U btcpay
docker exec btcpay psql -U btcpay -c "SELECT 1"
```

### Bitcoin Node Sync Status

```bash
docker exec btcpay bitcoin-cli -rpcuser=$BITCOIN_RPC_USER -rpcpassword=$BITCOIN_RPC_PASSWORD getblockchaininfo
```

## Ports Reference

| Port | Service | Internal | Exposed |
|------|---------|----------|---------|
| 49392 | BTCPay Server | Yes | Yes |
| 32838 | NBXplorer | Yes | No |
| 43782 | Bitcoin RPC | Yes | No |
| 39388 | Bitcoin P2P | Yes | Optional |
| 5432 | PostgreSQL | Yes | No |

## Resource Requirements

### Minimum (Pruned Node)
- CPU: 2 cores
- RAM: 4GB
- Storage: 20GB

### Recommended (Full Node)
- CPU: 4 cores
- RAM: 8GB
- Storage: 700GB+ (mainnet)

### Initial Sync Resources
During initial blockchain sync, more resources are beneficial:
- CPU: As many cores as available
- RAM: 8GB+ with larger dbcache
- Fast storage reduces sync time significantly
