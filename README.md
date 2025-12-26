# Docker Server Blockchain

Production-ready Docker deployment for BTCPay Server, optimized for Coolify and self-hosted environments.

[![License](https://img.shields.io/badge/License-EUPL--1.2-blue.svg)](LICENCE)

## Features

- **BTCPay Server** - Self-hosted Bitcoin payment processor
- **Bitcoin Core** - Full node with configurable pruning
- **NBXplorer** - Lightweight blockchain indexer
- **PostgreSQL** - Database backend with performance tuning
- **Lightning Network** - Optional CLN or LND integration
- **Coolify Ready** - Magic environment variables support
- **All-in-One Image** - Single container deployment option
- **Multi-Network** - Mainnet, testnet, signet, and regtest support

## Quick Start

### Local Development

```bash
# Clone the repository
git clone https://github.com/host-uk/docker-server-blockchain.git
cd docker-server-blockchain

# Copy environment file
cp .env.example .env

# Edit .env with your configuration
# For development, you can use defaults

# Start with regtest network
make dev

# Or manually
docker compose -f docker-compose.yaml -f docker-compose.dev.yml up -d
```

Access BTCPay Server at `http://localhost:49392`

### All-in-One (AIO) Image

For simpler deployments or NAS-backed storage, use the AIO image:

```bash
docker run -d \
  --name btcpay \
  -p 80:49392 \
  -v /mnt/nas/btcpay:/data \
  -e BTCPAY_HOST=btcpay.example.com \
  -e BTCPAY_PROTOCOL=https \
  ghcr.io/host-uk/docker-server-blockchain-aio:latest
```

See [docs/AIO.md](docs/AIO.md) for detailed AIO deployment guide.

### Coolify Deployment

1. Create a new **Docker Compose** resource in Coolify
2. Paste the contents of `docker-compose.coolify.yaml`
3. Set your domain in the Coolify UI for the `btcpayserver` service
4. Configure optional environment variables:
   - `BTCPAY_NETWORK` - Network (mainnet/testnet/signet)
   - `BITCOIN_PRUNE` - Pruning size (0 for full node)
5. Deploy

Coolify automatically generates:
- `SERVICE_FQDN_BTCPAYSERVER` - Your BTCPay domain
- `SERVICE_PASSWORD_POSTGRES` - Secure PostgreSQL password
- `SERVICE_USER_BITCOIN` / `SERVICE_PASSWORD_BITCOIN` - Bitcoin RPC credentials

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Coolify/Proxy                        │
│                    (Traefik/Nginx/Caddy)                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ :49392
┌─────────────────────────────────────────────────────────────┐
│                       BTCPay Server                         │
│                  (Payment Processing UI)                    │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌──────────────────────┐        ┌──────────────────────┐
│      NBXplorer       │        │      PostgreSQL      │
│  (Blockchain Index)  │        │      (Database)      │
└──────────────────────┘        └──────────────────────┘
              │
              ▼
┌──────────────────────┐
│     Bitcoin Core     │
│     (Full Node)      │
└──────────────────────┘
```

## Configuration

### Environment Variables

#### Required (Must be set)

| Variable | Description | Example |
|----------|-------------|---------|
| `BTCPAY_HOST` | Domain for BTCPay Server | `btcpay.example.com` |
| `POSTGRES_PASSWORD` | PostgreSQL password | `your_secure_password` |

#### Required with Defaults

| Variable | Default | Description |
|----------|---------|-------------|
| `BTCPAY_NETWORK` | `mainnet` | Bitcoin network |
| `BTCPAY_VERSION` | `2.0.6` | BTCPay Server version |
| `NBXPLORER_VERSION` | `2.5.16` | NBXplorer version |
| `BITCOIN_VERSION` | `28.0` | Bitcoin Core version |
| `POSTGRES_VERSION` | `16-alpine` | PostgreSQL version |
| `BITCOIN_RPC_USER` | `rpc` | Bitcoin RPC username |
| `BITCOIN_RPC_PASSWORD` | `rpcpassword` | Bitcoin RPC password |

#### Optional Features

| Variable | Default | Description |
|----------|---------|-------------|
| `BTCPAY_BTCLIGHTNING` | *(empty)* | Lightning connection string |
| `BITCOIN_PRUNE` | `0` | Prune size (0 = disabled) |
| `BITCOIN_DBCACHE` | `512` | Database cache in MB |
| `BITCOIN_MAXMEMPOOL` | `500` | Max mempool size in MB |

See `.env.example` for the complete list of configuration options.

### Network Configuration

| Network | Description | Use Case |
|---------|-------------|----------|
| `mainnet` | Bitcoin mainnet | Production |
| `testnet` | Bitcoin testnet | Testing with test coins |
| `signet` | Bitcoin signet | Stable testing |
| `regtest` | Regression test | Local development |

### Disk Space Requirements

| Configuration | Estimated Size |
|---------------|----------------|
| Full node (mainnet) | ~700 GB+ |
| Pruned node (550 MB) | ~5 GB |
| Testnet | ~50 GB |
| Regtest | ~100 MB |

## Compose Files

| File | Purpose |
|------|---------|
| `docker-compose.yaml` | Base production configuration |
| `docker-compose.dev.yml` | Development overrides (regtest) |
| `docker-compose.coolify.yaml` | Coolify-optimized with magic variables |
| `docker-compose.lightning.yml` | Core Lightning (CLN) addon |
| `docker-compose.lnd.yml` | LND addon |
| `Dockerfile` | All-in-One (AIO) image |

## Make Commands

```bash
make dev          # Start development environment
make up           # Start production environment
make down         # Stop all services
make logs         # View logs
make ps           # Show running services
make bitcoin-cli  # Access bitcoin-cli
make shell        # Shell into BTCPay container
make clean        # Remove all data volumes
```

## Lightning Network

Enable Lightning with compose overlay files:

### Core Lightning (CLN)
```bash
docker compose -f docker-compose.yaml -f docker-compose.lightning.yml up -d
```

### LND
```bash
docker compose -f docker-compose.yaml -f docker-compose.lnd.yml up -d
```

Both options include web UIs (RTL for CLN, ThunderHub for LND).

See [docs/LIGHTNING.md](docs/LIGHTNING.md) for detailed Lightning setup guide.

## Health Checks

All services include health checks:

- **BTCPay Server**: HTTP check on `:49392`
- **NBXplorer**: HTTP check on `:32838/health`
- **Bitcoin Core**: `bitcoin-cli getblockchaininfo`
- **PostgreSQL**: `pg_isready`

## Security Considerations

- Change default RPC credentials in production
- Use strong `POSTGRES_PASSWORD`
- Consider network segmentation for Bitcoin node
- Enable pruning if disk space is limited
- Regular backups of `postgres_datadir` and `btcpay_datadir`

## Troubleshooting

### Initial Sync

Bitcoin Core initial sync can take days. Monitor progress:

```bash
make bitcoin-cli getblockchaininfo
```

### Database Issues

Reset PostgreSQL if needed:

```bash
docker compose down
docker volume rm postgres_datadir
docker compose up -d
```

### Logs

```bash
# All services
make logs

# Specific service
docker compose logs -f btcpayserver
docker compose logs -f bitcoind
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## Security

See [SECURITY.md](SECURITY.md) for security policy and reporting vulnerabilities.

## License

This project is licensed under the EUPL-1.2 License. See [LICENCE](LICENCE) for details.

## Related Projects

- [BTCPay Server](https://btcpayserver.org/)
- [Docker Server PHP](https://github.com/host-uk/docker-server-php)
- [Coolify](https://coolify.io/)
