# Troubleshooting Guide

Common issues and solutions for docker-server-blockchain.

## Diagnostic Commands

### Check Service Status

```bash
# All services
docker compose ps

# Specific service
docker compose ps btcpayserver
docker compose ps bitcoind
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service (last 100 lines)
docker compose logs -f --tail 100 btcpayserver

# Since specific time
docker compose logs --since 1h btcpayserver
```

### Check Health

```bash
# Health check status
docker inspect --format='{{.State.Health.Status}}' <container>

# Detailed health info
docker inspect <container> | jq '.[0].State.Health'
```

## Common Issues

### Bitcoin Core Issues

#### Initial Sync Very Slow

**Symptoms**: Blockchain sync taking days, low CPU usage

**Solutions**:
1. Increase database cache:
   ```bash
   BITCOIN_DBCACHE=1024  # 1GB instead of 512MB
   ```

2. Ensure SSD storage (HDD is 10x slower)

3. Check bandwidth isn't throttled

4. Monitor progress:
   ```bash
   make bitcoin-cli ARGS="getblockchaininfo"
   ```

**Expected sync times**:
- Mainnet on SSD: 1-3 days
- Mainnet on HDD: 1-2 weeks
- Testnet: 4-12 hours
- Signet: 1-2 hours

#### "Error: Disk space is too low!"

**Symptoms**: Bitcoin Core stops syncing

**Solutions**:
1. Enable pruning:
   ```bash
   BITCOIN_PRUNE=550  # Minimum prune size in MB
   BITCOIN_TXINDEX=0  # Must disable txindex
   ```

2. Free disk space

3. Expand storage volume

#### RPC Connection Refused

**Symptoms**: NBXplorer can't connect to Bitcoin

**Checks**:
```bash
# Test RPC from host
docker compose exec bitcoind bitcoin-cli \
  -rpcuser=rpc -rpcpassword=rpcpassword \
  getblockchaininfo

# Check if bitcoind is listening
docker compose exec bitcoind netstat -tlnp | grep 43782
```

**Solutions**:
1. Verify RPC credentials match in all services
2. Check Bitcoin Core has started fully
3. Review bitcoind logs for startup errors

### NBXplorer Issues

#### "Waiting for Bitcoin Core..."

**Symptoms**: NBXplorer stuck waiting

**Causes**:
- Bitcoin Core still starting/syncing
- RPC connection issues
- Network mismatch

**Solutions**:
1. Wait for Bitcoin Core to fully start
2. Check RPC credentials
3. Verify same network in both services:
   ```bash
   docker compose exec bitcoind bitcoin-cli getnetworkinfo
   ```

#### Sync Taking Long Time

**Symptoms**: NBXplorer indexing slowly

**Context**: NBXplorer must index blockchain for tracked wallets

**Solutions**:
1. Wait - initial index takes hours
2. Check logs for errors
3. Restart if stuck:
   ```bash
   docker compose restart nbxplorer
   ```

### PostgreSQL Issues

#### Connection Refused

**Symptoms**: Services can't connect to database

**Checks**:
```bash
# Test connection
docker compose exec postgres pg_isready

# Check postgres is running
docker compose ps postgres
```

**Solutions**:
1. Wait for postgres to start (check health)
2. Verify password matches across services
3. Check postgres logs:
   ```bash
   docker compose logs postgres
   ```

#### Database Corruption

**Symptoms**: Postgres won't start, corruption errors

**Solutions**:
1. Check postgres logs for specific error
2. If minor, postgres may self-repair on restart
3. If major, restore from backup:
   ```bash
   docker compose down
   docker volume rm postgres_datadir
   # Restore backup
   docker compose up -d
   ```

#### Out of Connections

**Symptoms**: "too many connections" errors

**Solutions**:
1. Increase max connections:
   ```bash
   POSTGRES_MAX_CONNECTIONS=300
   ```

2. Reduce connection pool sizes:
   ```bash
   NBXPLORER_POSTGRES_MAXPOOL=10
   ```

### BTCPay Server Issues

#### "NBXplorer is not available"

**Symptoms**: BTCPay shows NBXplorer unavailable

**Causes**:
- NBXplorer not running/healthy
- NBXplorer still syncing
- Network issues

**Solutions**:
1. Check NBXplorer status:
   ```bash
   docker compose ps nbxplorer
   curl http://localhost:32838/health  # In dev mode
   ```

2. Check BTCPay → NBXplorer connection:
   ```bash
   docker compose exec btcpayserver curl http://nbxplorer:32838/health
   ```

3. Wait for NBXplorer sync to complete

#### Login Page Not Loading

**Symptoms**: Blank page, 502 errors

**Causes**:
- BTCPay still starting
- Proxy misconfiguration
- Resource exhaustion

**Solutions**:
1. Check BTCPay health:
   ```bash
   docker compose exec btcpayserver curl -f http://localhost:49392/
   ```

2. Check logs for errors:
   ```bash
   docker compose logs btcpayserver
   ```

3. Verify proxy routing (Coolify/Traefik)

#### Payment Not Detected

**Symptoms**: Invoice paid but not updating

**Causes**:
- NBXplorer not synced
- Wrong network (mainnet vs testnet)
- Transaction not broadcast

**Solutions**:
1. Check NBXplorer sync status
2. Verify payment on blockchain explorer
3. Check BTCPay logs for payment events
4. Restart NBXplorer to force rescan

### Docker/Container Issues

#### Container Keeps Restarting

**Symptoms**: Container in restart loop

**Diagnosis**:
```bash
# Check exit code
docker compose ps

# View last logs before crash
docker compose logs --tail 50 <service>
```

**Common causes**:
- Missing environment variable
- Port conflict
- Volume permission issue
- OOM killed

#### Out of Memory (OOM)

**Symptoms**: Container killed, "OOMKilled: true"

**Solutions**:
1. Increase host RAM
2. Add swap space
3. Reduce service memory:
   ```bash
   BITCOIN_DBCACHE=256
   POSTGRES_SHARED_BUFFERS=128MB
   ```

4. Enable pruning for Bitcoin

#### Volume Permission Errors

**Symptoms**: "Permission denied" in logs

**Solutions**:
```bash
# Fix ownership (if needed)
docker compose down
sudo chown -R 1000:1000 /var/lib/docker/volumes/<volume>/_data
docker compose up -d
```

### Network Issues

#### Services Can't Communicate

**Symptoms**: Connection refused between services

**Checks**:
```bash
# Check network exists
docker network ls | grep blockchain

# Check services on same network
docker network inspect <network>
```

**Solutions**:
1. Recreate containers:
   ```bash
   docker compose down
   docker compose up -d
   ```

2. Check service names match connection strings

#### External Access Issues

**Symptoms**: Can't access from outside

**For development**:
- Verify ports are exposed in docker-compose.dev.yml
- Check firewall rules

**For production/Coolify**:
- Verify domain DNS
- Check proxy configuration
- Review SSL certificate status

## Recovery Procedures

### Full Reset

**Warning**: Destroys all data!

```bash
docker compose down -v --remove-orphans
docker compose up -d
```

### Reset Specific Service

```bash
# Example: Reset PostgreSQL
docker compose down
docker volume rm postgres_datadir
docker compose up -d postgres
# Wait for healthy
docker compose up -d
```

### Restore from Backup

```bash
# Stop services
docker compose down

# Restore PostgreSQL
docker compose up -d postgres
cat backup.sql | docker compose exec -T postgres psql -U postgres

# Restore volumes
docker run --rm -v btcpay_datadir:/data -v $(pwd):/backup \
  alpine tar xzf /backup/btcpay_data.tar.gz -C /data

# Start services
docker compose up -d
```

## Getting Help

### Information to Gather

1. Docker Compose version: `docker compose version`
2. Service versions (from .env or compose)
3. Relevant logs (last 100 lines)
4. Error messages (exact text)
5. Steps to reproduce

### Resources

- [BTCPay Server Documentation](https://docs.btcpayserver.org/)
- [BTCPay Server GitHub Issues](https://github.com/btcpayserver/btcpayserver/issues)
- [Bitcoin Core Documentation](https://bitcoin.org/en/developer-documentation)
- [NBXplorer GitHub](https://github.com/dgarage/NBXplorer)
