# Configuration Reference

Complete reference for all configuration options in docker-server-blockchain.

## Environment Variable Syntax

This project uses shell parameter expansion for configuration:

```bash
# Required - fails with error if not set
${VARIABLE:?error message}

# Required with default - uses default if not set
${VARIABLE:-default}

# Coolify pattern for required with UI default
${VARIABLE:?8080}  # Shows 8080 in Coolify UI, requires value
```

## BTCPay Server Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `BTCPAY_HOST` | Domain name for BTCPay Server | `btcpay.example.com` |

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `BTCPAY_VERSION` | `2.0.6` | BTCPay Server image version |
| `BTCPAY_NETWORK` | `mainnet` | Bitcoin network (mainnet/testnet/signet/regtest) |
| `BTCPAY_BIND` | `0.0.0.0:49392` | Binding address and port |
| `BTCPAY_ROOTPATH` | `/` | URL root path (for reverse proxy) |
| `BTCPAY_PROTOCOL` | `https` | Protocol (http/https) |

### Database Connection

| Variable | Default | Description |
|----------|---------|-------------|
| `BTCPAY_POSTGRES` | (constructed) | Full PostgreSQL connection string |

The connection string is constructed from:
```
Host=postgres;Port=5432;Database=btcpay${BTCPAY_NETWORK};Username=postgres;Password=${POSTGRES_PASSWORD}
```

### Optional Features

| Variable | Default | Description |
|----------|---------|-------------|
| `BTCPAY_BTCLIGHTNING` | *(empty)* | Lightning Network connection string |
| `BTCPAY_DOCKERDEPLOYMENT` | `true` | Enable Docker deployment features |
| `BTCPAY_SSH_CONNECTION` | *(empty)* | SSH connection for remote management |
| `BTCPAY_SSHKEYFILE` | *(empty)* | Path to SSH key file |
| `BTCPAY_UPDATEURL` | *(empty)* | URL for in-app update checks |

### Debugging

| Variable | Default | Description |
|----------|---------|-------------|
| `BTCPAY_DEBUGLOG` | *(empty)* | Path to debug log file |
| `ASPNETCORE_ENVIRONMENT` | `Production` | ASP.NET environment (Production/Development) |

## NBXplorer Configuration

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `NBXPLORER_VERSION` | `2.5.16` | NBXplorer image version |
| `NBXPLORER_BIND` | `0.0.0.0:32838` | Binding address and port |
| `NBXPLORER_TRIMEVENTS` | `10000` | Event trimming threshold |

### Database Connection

| Variable | Default | Description |
|----------|---------|-------------|
| `NBXPLORER_POSTGRES_MAXPOOL` | `20` | Maximum PostgreSQL connection pool size |

Connection string format:
```
Host=postgres;Port=5432;Database=nbxplorer${BTCPAY_NETWORK};Username=postgres;Password=${POSTGRES_PASSWORD};MaxPoolSize=20;Application Name=nbxplorer
```

### Bitcoin Node Connection

| Variable | Default | Description |
|----------|---------|-------------|
| `BITCOIN_RPC_USER` | `rpc` | Bitcoin RPC username |
| `BITCOIN_RPC_PASSWORD` | `rpcpassword` | Bitcoin RPC password |

Internal settings (auto-configured):
- `NBXPLORER_BTCRPCURL`: `http://bitcoind:43782/`
- `NBXPLORER_BTCNODEENDPOINT`: `bitcoind:39388`

### Advanced Options

| Variable | Default | Description |
|----------|---------|-------------|
| `NBXPLORER_NOAUTH` | `1` | Disable authentication (internal use) |
| `NBXPLORER_EXPOSERPC` | `1` | Expose RPC methods |

## Bitcoin Core Configuration

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `BITCOIN_VERSION` | `28.0` | Bitcoin Core image version |
| `BITCOIN_RPC_USER` | `rpc` | RPC authentication username |
| `BITCOIN_RPC_PASSWORD` | `rpcpassword` | RPC authentication password |

### Performance Tuning

| Variable | Default | Description |
|----------|---------|-------------|
| `BITCOIN_MAXMEMPOOL` | `500` | Maximum mempool size in MB |
| `BITCOIN_DBCACHE` | `512` | Database cache size in MB |

### Storage Options

| Variable | Default | Description |
|----------|---------|-------------|
| `BITCOIN_PRUNE` | `0` | Prune mode (0=disabled, >550=prune to N MB) |
| `BITCOIN_TXINDEX` | `1` | Transaction index (1=enabled, 0=disabled) |
| `BITCOIN_CREATE_WALLET` | `false` | Create default wallet on startup |

### Pruning vs Full Node

**Full Node (default):**
```bash
BITCOIN_PRUNE=0
BITCOIN_TXINDEX=1
# Requires ~700GB+ disk space for mainnet
```

**Pruned Node:**
```bash
BITCOIN_PRUNE=550  # Minimum pruning size in MB
BITCOIN_TXINDEX=0  # Must be disabled when pruning
# Requires ~5GB disk space
```

### Network Configuration

Ports configured via `BITCOIN_EXTRA_ARGS`:

| Port | Purpose |
|------|---------|
| 43782 | JSON-RPC API |
| 39388 | P2P Network |
| 28332 | ZMQ raw block |
| 28333 | ZMQ raw tx |
| 28334 | ZMQ hash block |

## PostgreSQL Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `POSTGRES_PASSWORD` | Database password | `secure_password_here` |

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_VERSION` | `16-alpine` | PostgreSQL image version |
| `POSTGRES_USER` | `postgres` | Database superuser name |
| `POSTGRES_DB` | `btcpaymainnet` | Default database name |
| `POSTGRES_SHM_SIZE` | `256mb` | Shared memory size |

### Performance Tuning

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_MAX_CONNECTIONS` | `200` | Maximum concurrent connections |
| `POSTGRES_SHARED_BUFFERS` | `256MB` | Shared buffer pool size |
| `POSTGRES_EFFECTIVE_CACHE` | `1GB` | Effective cache size hint |
| `POSTGRES_HOST_AUTH_METHOD` | `scram-sha-256` | Authentication method |

### Performance Command Arguments

The PostgreSQL container runs with these optimizations:
```bash
-c random_page_cost=1.0           # SSD optimization
-c shared_preload_libraries=pg_stat_statements  # Query stats
```

## Network-Specific Configuration

### Mainnet (Production)

```bash
BTCPAY_NETWORK=mainnet
BITCOIN_PRUNE=0        # Full node recommended
BITCOIN_TXINDEX=1
```

### Testnet

```bash
BTCPAY_NETWORK=testnet
BITCOIN_PRUNE=0        # ~50GB storage needed
BITCOIN_TXINDEX=1
```

### Signet

```bash
BTCPAY_NETWORK=signet
BITCOIN_PRUNE=0        # Minimal storage
BITCOIN_TXINDEX=1
```

### Regtest (Development)

```bash
BTCPAY_NETWORK=regtest
BITCOIN_CREATE_WALLET=true  # Auto-create wallet
```

## Lightning Network Configuration

### LND Connection

```bash
BTCPAY_BTCLIGHTNING=type=lnd-rest;server=https://lnd:8080;macaroonfilepath=/lnd/admin.macaroon;allowinsecure=true
```

Required LND container mounts:
- Macaroon file accessible to BTCPay
- TLS certificate if not using `allowinsecure`

### Core Lightning (CLN)

```bash
BTCPAY_BTCLIGHTNING=type=clightning;server=unix://root/.lightning/bitcoin/lightning-rpc
```

Required CLN container mounts:
- Lightning RPC socket accessible to BTCPay

## Coolify-Specific Variables

When deploying to Coolify, these magic variables are auto-generated:

| Variable | Pattern | Description |
|----------|---------|-------------|
| `SERVICE_FQDN_<NAME>` | Domain | Fully qualified domain name |
| `SERVICE_URL_<NAME>` | URL | Complete URL with protocol |
| `SERVICE_USER_<NAME>` | String | Random 16-character username |
| `SERVICE_PASSWORD_<NAME>` | Password | Secure random password |
| `SERVICE_PASSWORD_64_<NAME>` | Password | 64-character password |
| `SERVICE_BASE64_<NAME>` | String | Random 32-character base64 |
| `SERVICE_BASE64_64_<NAME>` | String | 64-character base64 |

### Usage in Coolify

```yaml
environment:
  # Auto-generated domain from Coolify UI
  BTCPAY_HOST: ${SERVICE_FQDN_BTCPAYSERVER}

  # Auto-generated secure password
  POSTGRES_PASSWORD: ${SERVICE_PASSWORD_POSTGRES}

  # Auto-generated RPC credentials
  BITCOIN_RPC_USER: ${SERVICE_USER_BITCOIN}
  BITCOIN_RPC_PASSWORD: ${SERVICE_PASSWORD_BITCOIN}
```

## Environment Files

### .env.example

Template with all variables and documentation. Copy to `.env` for local use.

### Development .env

Minimal configuration for local development:

```bash
BTCPAY_HOST=localhost
BTCPAY_NETWORK=regtest
POSTGRES_PASSWORD=devpassword
BITCOIN_RPC_USER=rpc
BITCOIN_RPC_PASSWORD=rpcpassword
```

### Production .env

Secure configuration for production:

```bash
BTCPAY_HOST=btcpay.yourdomain.com
BTCPAY_NETWORK=mainnet
POSTGRES_PASSWORD=<long-random-password>
BITCOIN_RPC_USER=<random-username>
BITCOIN_RPC_PASSWORD=<long-random-password>
```
