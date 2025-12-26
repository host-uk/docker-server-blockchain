# Lightning Network Setup Guide

## Overview

BTCPay Server supports Lightning Network payments through either:
- **Core Lightning (CLN)** - Formerly c-lightning, by Blockstream
- **LND** - Lightning Network Daemon, by Lightning Labs

Both implementations are provided as Docker Compose overlay files.

## Quick Comparison

| Feature | Core Lightning | LND |
|---------|---------------|-----|
| Resource Usage | Lower | Higher |
| Plugin System | Extensive | Limited |
| UI Options | RTL | ThunderHub, RTL, Zap |
| Maturity | Older, stable | Widely adopted |
| Documentation | Good | Excellent |

## Core Lightning (CLN) Setup

### Basic Setup

```bash
# Start base stack with CLN
docker compose -f docker-compose.yaml -f docker-compose.lightning.yml up -d

# For Coolify deployment
docker compose -f docker-compose.coolify.yaml -f docker-compose.lightning.yml up -d
```

### Configuration

Environment variables in `.env`:

```env
# CLN Configuration
CLN_VERSION=v24.11
CLN_ALIAS=MyBTCPayNode
CLN_RGB=FF6600
CLN_ANNOUNCE_ADDR=your.public.ip:9735

# RTL Web Interface
RTL_VERSION=0.15.2
RTL_PASSWORD=your-secure-password
```

### Accessing RTL

RTL (Ride The Lightning) provides a web interface for CLN:

```bash
# Check RTL status
docker compose logs rtl

# RTL is available on port 3000
# Access via reverse proxy or direct port mapping
```

### CLN Commands

```bash
# Get node info
docker compose exec clightning lightning-cli getinfo

# Check balance
docker compose exec clightning lightning-cli listfunds

# Open channel
docker compose exec clightning lightning-cli connect <node_id>@<ip>:<port>
docker compose exec clightning lightning-cli fundchannel <node_id> <amount_sat>

# Create invoice
docker compose exec clightning lightning-cli invoice <amount_msat> <label> <description>
```

## LND Setup

### Basic Setup

```bash
# Start base stack with LND
docker compose -f docker-compose.yaml -f docker-compose.lnd.yml up -d

# For Coolify deployment
docker compose -f docker-compose.coolify.yaml -f docker-compose.lnd.yml up -d
```

### Configuration

Environment variables in `.env`:

```env
# LND Configuration
LND_VERSION=v0.18.4-beta
LND_ALIAS=MyBTCPayNode
LND_COLOR=#FF6600

# ThunderHub Web Interface
THUNDERHUB_VERSION=v0.13.31
```

### First-Time LND Setup

LND requires wallet creation on first run:

```bash
# Create wallet (interactive)
docker compose exec lnd lncli create

# Or unlock existing wallet
docker compose exec lnd lncli unlock
```

### Accessing ThunderHub

ThunderHub provides a web interface for LND:

```bash
# ThunderHub is available on port 3000
# Create config file for authentication
docker compose exec thunderhub cat /data/thubConfig.yaml
```

### LND Commands

```bash
# Get node info
docker compose exec lnd lncli getinfo

# Check balance
docker compose exec lnd lncli walletbalance
docker compose exec lnd lncli channelbalance

# Open channel
docker compose exec lnd lncli connect <node_pubkey>@<host>:<port>
docker compose exec lnd lncli openchannel <node_pubkey> <local_amt>

# Create invoice
docker compose exec lnd lncli addinvoice --amt <amount_sat> --memo "description"
```

## BTCPay Server Integration

Both Lightning implementations automatically integrate with BTCPay Server through the compose overlay files.

### Verify Connection

1. Go to BTCPay Server admin
2. Navigate to Server Settings → Services
3. Verify Lightning node shows "Connected"

### Store Configuration

1. Open your store settings
2. Go to Lightning → Settings
3. Verify "Internal Node" is selected
4. Test connection

## Channel Management Best Practices

### Opening Channels

1. **Choose reliable peers** - Look for well-connected nodes
2. **Adequate capacity** - Open channels large enough for expected payments
3. **Balanced channels** - Aim for ~50% local/remote balance for routing

### Recommended Peers

Connect to well-established routing nodes:
- ACINQ
- Bitrefill
- OpenNode
- River Financial

```bash
# Example: Connect to ACINQ (mainnet)
# CLN
docker compose exec clightning lightning-cli connect 03864ef025fde8fb587d989186ce6a4a186895ee44a926bfc370e2c366597a3f8f@34.239.230.56:9735

# LND
docker compose exec lnd lncli connect 03864ef025fde8fb587d989186ce6a4a186895ee44a926bfc370e2c366597a3f8f@34.239.230.56:9735
```

## Backup

### CLN Backup

```bash
# Backup CLN data
docker compose exec clightning lightning-cli backup

# Copy hsm_secret (CRITICAL - keep secure!)
docker cp $(docker compose ps -q clightning):/data/bitcoin/hsm_secret ./hsm_secret.backup
```

### LND Backup

```bash
# Backup channel database
docker cp $(docker compose ps -q lnd):/data/.lnd/data/chain/bitcoin/mainnet/channel.backup ./channel.backup

# Backup seed (write down during wallet creation!)
```

## Troubleshooting

### Node Not Syncing

```bash
# Check Bitcoin Core sync status first
docker compose exec bitcoind bitcoin-cli getblockchaininfo

# Lightning won't sync until Bitcoin is fully synced
```

### Cannot Connect to Peers

1. Ensure port 9735 is forwarded/open
2. Check `CLN_ANNOUNCE_ADDR` or LND `--externalip` is set
3. Verify network connectivity

```bash
# Check if port is reachable
nc -zv your.public.ip 9735
```

### BTCPay Not Detecting Lightning

```bash
# Check socket/connection file exists
# For CLN
docker compose exec btcpayserver ls -la /cln-data/

# For LND
docker compose exec btcpayserver ls -la /lnd-data/
```

### Channel Force-Closed

This can happen if your node goes offline for extended periods:
1. Wait for funds to return to on-chain wallet (can take days)
2. Maintain good uptime to avoid this
3. Consider running on reliable infrastructure

## Resources

- [CLN Documentation](https://docs.corelightning.org/)
- [LND Documentation](https://docs.lightning.engineering/)
- [BTCPay Lightning Docs](https://docs.btcpayserver.org/Lightning/)
- [1ML - Lightning Explorer](https://1ml.com/)
