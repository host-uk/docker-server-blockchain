# Architecture Documentation

This document provides a comprehensive overview of the docker-server-blockchain architecture for BTCPay Server deployment.

## System Overview

This repository provides a production-ready Docker deployment of BTCPay Server, a self-hosted Bitcoin payment processor. The architecture consists of four core services that work together to provide a complete payment processing solution.

## Service Architecture

### Component Diagram

```
                    ┌─────────────────────────────────────────┐
                    │           External Traffic              │
                    │        (HTTPS via Coolify/Proxy)        │
                    └───────────────────┬─────────────────────┘
                                        │
                                        ▼ Port 49392
┌───────────────────────────────────────────────────────────────────────────┐
│                            BTCPay Server                                  │
│                                                                           │
│  • Web UI for merchants and administrators                                │
│  • Invoice generation and payment processing                              │
│  • Wallet management                                                      │
│  • Plugin system for extensions                                           │
│  • API for integrations                                                   │
│                                                                           │
│  Image: btcpayserver/btcpayserver:2.0.6                                   │
│  Port: 49392                                                              │
└───────────────────────────────────────────────────────────────────────────┘
         │                                        │
         │ PostgreSQL Connection                  │ HTTP API
         │ (payment data, users, stores)          │ (blockchain queries)
         ▼                                        ▼
┌────────────────────────┐           ┌────────────────────────────────────┐
│      PostgreSQL        │           │           NBXplorer                │
│                        │           │                                    │
│  • User accounts       │           │  • Lightweight blockchain indexer  │
│  • Store configuration │           │  • Tracks wallet transactions      │
│  • Invoice history     │           │  • Monitors addresses              │
│  • Payment records     │           │  • Provides UTXO tracking          │
│  • Plugin data         │           │                                    │
│                        │           │  Image: nicolasdorier/nbxplorer    │
│  Image: postgres:16    │           │  Port: 32838                       │
│  Port: 5432            │           └────────────────────────────────────┘
└────────────────────────┘                        │
         ▲                                        │ RPC + P2P
         │ PostgreSQL Connection                  │ (blockchain data)
         │ (blockchain index data)                ▼
         │                           ┌────────────────────────────────────┐
         └───────────────────────────│          Bitcoin Core              │
                                     │                                    │
                                     │  • Full Bitcoin node               │
                                     │  • Validates all transactions      │
                                     │  • Maintains blockchain copy       │
                                     │  • Provides RPC interface          │
                                     │  • ZMQ notifications               │
                                     │                                    │
                                     │  Image: btcpayserver/bitcoin:28.0  │
                                     │  RPC: 43782, P2P: 39388            │
                                     │  ZMQ: 28332-28334                  │
                                     └────────────────────────────────────┘
```

## Data Flow

### Payment Processing Flow

1. **Invoice Creation**
   - Merchant creates invoice via BTCPay UI/API
   - BTCPay generates unique Bitcoin address from HD wallet
   - Invoice stored in PostgreSQL with payment details

2. **Payment Monitoring**
   - NBXplorer monitors registered addresses
   - Bitcoin Core provides real-time blockchain data via ZMQ
   - NBXplorer indexes transactions and notifies BTCPay

3. **Payment Confirmation**
   - BTCPay receives notification from NBXplorer
   - Waits for configured number of confirmations
   - Updates invoice status in PostgreSQL
   - Triggers webhooks/notifications to merchant

### Service Communication

```
BTCPay Server ──HTTP──► NBXplorer ──RPC──► Bitcoin Core
      │                     │
      │                     │
      └──────PostgreSQL─────┘
```

## Configuration Architecture

### Environment Variable Hierarchy

Variables follow this priority (highest to lowest):
1. Coolify magic variables (auto-generated)
2. User-defined environment variables
3. Default values in compose files
4. Service defaults

### Variable Patterns

```yaml
# Required - fails if not set
BTCPAY_HOST: ${BTCPAY_HOST:?error message}

# Required with default
BTCPAY_NETWORK: ${BTCPAY_NETWORK:-mainnet}

# Optional
BTCPAY_DEBUGLOG: ${BTCPAY_DEBUGLOG:-}
```

### Coolify Magic Variables

Coolify auto-generates these variables:

| Variable | Purpose | Example |
|----------|---------|---------|
| `SERVICE_FQDN_BTCPAYSERVER` | Domain name | `btcpay.example.com` |
| `SERVICE_URL_BTCPAYSERVER` | Full URL | `https://btcpay.example.com` |
| `SERVICE_PASSWORD_POSTGRES` | DB password | `randomsecurepassword` |
| `SERVICE_USER_BITCOIN` | RPC username | `randomstring` |
| `SERVICE_PASSWORD_BITCOIN` | RPC password | `randompassword` |

## Volume Architecture

### Persistent Data Volumes

| Volume | Service | Purpose | Size (Mainnet) |
|--------|---------|---------|----------------|
| `bitcoin_datadir` | bitcoind | Blockchain data | ~700 GB |
| `bitcoin_wallet_datadir` | bitcoind | Wallet files | ~100 MB |
| `postgres_datadir` | postgres | Database | ~5 GB |
| `nbxplorer_datadir` | nbxplorer | Index cache | ~2 GB |
| `btcpay_datadir` | btcpayserver | App data | ~500 MB |
| `btcpay_plugins` | btcpayserver | Plugin files | ~200 MB |

### Volume Mount Points

```yaml
bitcoind:
  volumes:
    - bitcoin_datadir:/data           # Blockchain
    - bitcoin_wallet_datadir:/walletdata  # Wallets

postgres:
  volumes:
    - postgres_datadir:/var/lib/postgresql/data

nbxplorer:
  volumes:
    - nbxplorer_datadir:/datadir

btcpayserver:
  volumes:
    - btcpay_datadir:/datadir
    - nbxplorer_datadir:/root/.nbxplorer  # Shared for status
    - btcpay_plugins:/root/.btcpayserver/Plugins
```

## Network Architecture

### Internal Docker Network

All services communicate on an internal Docker bridge network:

```
┌──────────────────────────────────────────────────────────┐
│                  Docker Bridge Network                   │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │btcpayserv│  │nbxplorer │  │ bitcoind │  │ postgres │ │
│  │  :49392  │  │  :32838  │  │  :43782  │  │  :5432   │ │
│  └──────────┘  └──────────┘  │  :39388  │  └──────────┘ │
│                              └──────────┘               │
└──────────────────────────────────────────────────────────┘
```

### Port Mappings

| Service | Internal Port | Purpose | External (Dev) |
|---------|---------------|---------|----------------|
| btcpayserver | 49392 | HTTP UI/API | 49392 |
| nbxplorer | 32838 | HTTP API | 32838 |
| bitcoind | 43782 | JSON-RPC | 43782 |
| bitcoind | 39388 | P2P Network | 39388 |
| bitcoind | 28332 | ZMQ Block | 28332 |
| bitcoind | 28333 | ZMQ TX | 28333 |
| postgres | 5432 | PostgreSQL | 5432 |

## Health Check Architecture

### Service Health Endpoints

```yaml
btcpayserver:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:49392/"]
    interval: 30s
    start_period: 60s  # Wait for app initialization

nbxplorer:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:32838/health"]
    interval: 30s
    start_period: 120s  # Wait for initial sync

bitcoind:
  healthcheck:
    test: ["CMD", "bitcoin-cli", "getblockchaininfo"]
    interval: 60s
    start_period: 300s  # Initial sync can take time

postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U postgres"]
    interval: 10s
    start_period: 30s
```

### Dependency Chain

```
postgres (healthy)
    ↓
nbxplorer (started) ← bitcoind (started)
    ↓
btcpayserver (started)
```

## Deployment Modes

### Production (docker-compose.yaml)

- All services internal (no exposed ports)
- Requires reverse proxy (Coolify/Traefik/Nginx)
- TLS termination at proxy level
- Optimized for security

### Development (docker-compose.dev.yml)

- All ports exposed locally
- Regtest network (instant blocks)
- Debug logging enabled
- Relaxed security for testing

### Coolify (docker-compose.coolify.yaml)

- Uses Coolify magic variables
- Auto-generated credentials
- Integrated with Coolify proxy
- Simplified configuration
