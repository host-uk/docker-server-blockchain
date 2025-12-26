# Coolify Deployment Guide

Complete guide for deploying docker-server-blockchain to Coolify.

## What is Coolify?

Coolify is an open-source, self-hosted alternative to Heroku/Netlify/Vercel. It provides:

- Automatic HTTPS via Let's Encrypt
- Docker Compose support
- Environment variable management
- "Magic" auto-generated variables
- Built-in reverse proxy (Traefik)

## Prerequisites

1. A Coolify server instance
2. A domain pointed to your Coolify server
3. Sufficient resources:
   - **Mainnet Full Node**: 16GB+ RAM, 1TB+ SSD
   - **Mainnet Pruned**: 4GB+ RAM, 50GB+ SSD
   - **Testnet/Signet**: 4GB+ RAM, 100GB+ SSD
   - **Regtest**: 2GB RAM, 10GB disk

## Deployment Steps

### 1. Create Docker Compose Resource

1. In Coolify dashboard, click **+ Add Resource**
2. Select **Docker Compose**
3. Choose your destination server

### 2. Configure the Compose File

Paste the contents of `docker-compose.coolify.yaml` into the compose editor.

### 3. Set the Domain

1. In the **btcpayserver** service settings
2. Set your domain (e.g., `btcpay.yourdomain.com`)
3. Coolify auto-generates `SERVICE_FQDN_BTCPAYSERVER`

### 4. Configure Environment Variables

In the Coolify UI, configure these variables:

**Required:**
| Variable | Value |
|----------|-------|
| `BTCPAY_NETWORK` | `mainnet` (or testnet/signet) |

**Optional:**
| Variable | Default | Description |
|----------|---------|-------------|
| `BITCOIN_PRUNE` | `0` | Set >550 for pruned node |
| `BITCOIN_DBCACHE` | `512` | Increase for faster sync |

### 5. Deploy

Click **Deploy** and wait for services to start.

**Important**: Initial Bitcoin sync takes hours to days depending on network and hardware.

## Coolify Magic Variables

### Auto-Generated Variables

Coolify automatically generates secure values for:

```yaml
SERVICE_FQDN_BTCPAYSERVER     # Your configured domain
SERVICE_PASSWORD_POSTGRES     # Secure PostgreSQL password
SERVICE_USER_BITCOIN          # Random RPC username
SERVICE_PASSWORD_BITCOIN      # Secure RPC password
```

### How Magic Variables Work

When Coolify deploys the compose file, it:

1. Detects variable patterns like `${SERVICE_PASSWORD_POSTGRES}`
2. Generates secure random values
3. Stores them persistently
4. Injects them at runtime

Variables persist across restarts and redeployments.

### Variable Naming Rules

- Use `SERVICE_<TYPE>_<IDENTIFIER>`
- Identifiers with ports use hyphens: `SERVICE_URL_BTCPAY-SERVER_49392`
- Underscores in identifiers block port specification

## Compose File Differences

### Standard vs Coolify Compose

| Feature | Standard | Coolify |
|---------|----------|---------|
| Credentials | Manual | Auto-generated |
| Domain | Environment var | UI + magic var |
| SSL/TLS | Manual/proxy | Automatic |
| Port exposure | Required | Via domain |

### Key Coolify Compose Changes

```yaml
# Standard
POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?}

# Coolify
POSTGRES_PASSWORD: ${SERVICE_PASSWORD_POSTGRES}
```

```yaml
# Standard
BTCPAY_HOST: ${BTCPAY_HOST:?}

# Coolify
BTCPAY_HOST: ${SERVICE_FQDN_BTCPAYSERVER:?Set domain in Coolify UI}
```

## Networking in Coolify

### Automatic Proxy Configuration

Coolify's Traefik proxy:
- Terminates HTTPS
- Routes to btcpayserver:49392
- Handles Let's Encrypt certificates

### Labels for Routing

The compose includes Coolify-compatible labels:

```yaml
labels:
  - "coolify.managed=true"
  - "coolify.port=49392"
```

### Cross-Stack Communication

To connect to services in other Coolify stacks:

1. Enable "Connect to Predefined Network" in both stacks
2. Reference services as `servicename-<uuid>`

## Storage in Coolify

### Volume Persistence

Named volumes persist across:
- Container restarts
- Redeployments
- Image updates

```yaml
volumes:
  bitcoin_datadir:    # ~700GB mainnet
  postgres_datadir:   # Database files
```

### Backup Considerations

Coolify stores volumes in:
```
/var/lib/docker/volumes/
```

Backup strategy:
1. Stop services (or use consistent snapshots)
2. Backup volume directories
3. Store PostgreSQL dump separately

## Monitoring in Coolify

### Health Checks

All services include health checks visible in Coolify UI:

- Green: Service healthy
- Yellow: Starting/checking
- Red: Failed

### Logs

View logs in Coolify UI or via:
```bash
# SSH to Coolify server
docker logs <container_name> -f
```

## Troubleshooting Coolify Deployments

### Service Won't Start

1. Check Coolify logs for the service
2. Verify domain is correctly configured
3. Check for port conflicts

### SSL/HTTPS Issues

1. Ensure domain points to Coolify server
2. Check Traefik logs: `docker logs coolify-traefik`
3. Verify Let's Encrypt rate limits

### Database Connection Errors

1. Check `SERVICE_PASSWORD_POSTGRES` is set
2. Verify postgres container is healthy
3. Check service dependency order

### Initial Sync Hanging

Bitcoin initial sync is slow. Monitor progress:

```bash
docker exec <bitcoin_container> bitcoin-cli \
  -rpcuser=$(docker exec <bitcoin_container> printenv SERVICE_USER_BITCOIN) \
  -rpcpassword=$(docker exec <bitcoin_container> printenv SERVICE_PASSWORD_BITCOIN) \
  getblockchaininfo
```

## Advanced Coolify Configuration

### Custom Traefik Labels

Add custom routing rules:

```yaml
labels:
  - "traefik.http.routers.btcpay.middlewares=custom-headers"
```

### Resource Limits

Add resource constraints:

```yaml
deploy:
  resources:
    limits:
      memory: 4G
    reservations:
      memory: 2G
```

### Multiple Environments

Create separate Coolify projects for:
- Production (mainnet)
- Staging (testnet)
- Development (regtest)

## Updating in Coolify

### Image Updates

1. Change version in environment variables
2. Click **Redeploy**

Example:
```
BTCPAY_VERSION=2.1.0  # Update from 2.0.6
```

### Compose Updates

1. Edit compose in Coolify UI
2. Click **Deploy**

### Data Preservation

Volumes persist during updates. Only reset volumes if:
- Switching networks (mainnet → testnet)
- Major schema changes (rare)
- Troubleshooting data corruption
