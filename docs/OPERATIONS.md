# Operations Guide

Day-to-day operations, maintenance, and administration for docker-server-blockchain.

## Daily Operations

### Health Monitoring

```bash
# Quick status check
make health

# Detailed status
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# Container resource usage
docker stats --no-stream
```

### Log Review

```bash
# Recent errors across all services
docker compose logs --since 1h 2>&1 | grep -i error

# BTCPay application logs
docker compose logs --tail 100 btcpayserver

# Bitcoin Core sync progress
make bitcoin-cli ARGS="getblockchaininfo" | jq '{blocks, headers, verificationprogress}'
```

## Backup Procedures

### Automated Backup Script

```bash
./scripts/backup.sh
```

This creates:
- PostgreSQL dump
- BTCPay data archive
- BTCPay plugins archive

### Manual PostgreSQL Backup

```bash
# Full database dump
docker compose exec -T postgres pg_dumpall -U postgres > backup_$(date +%Y%m%d).sql

# Compressed backup
docker compose exec -T postgres pg_dumpall -U postgres | gzip > backup_$(date +%Y%m%d).sql.gz
```

### Volume Backup

```bash
# Stop services for consistent backup
docker compose stop

# Backup specific volume
docker run --rm \
  -v btcpay_datadir:/data:ro \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/btcpay_$(date +%Y%m%d).tar.gz -C /data .

# Restart services
docker compose start
```

### Backup Rotation

Recommended retention:
- Daily: 7 days
- Weekly: 4 weeks
- Monthly: 12 months

Example cron:
```bash
# Daily backup at 3 AM
0 3 * * * /path/to/backup.sh

# Weekly cleanup (keep 7 daily)
0 4 * * 0 find /backups -name "*.sql" -mtime +7 -delete
```

## Restore Procedures

### PostgreSQL Restore

```bash
# Stop dependent services
docker compose stop btcpayserver nbxplorer

# Drop and recreate databases
docker compose exec postgres psql -U postgres -c "DROP DATABASE IF EXISTS btcpaymainnet;"
docker compose exec postgres psql -U postgres -c "DROP DATABASE IF EXISTS nbxplorermainnet;"

# Restore from backup
cat backup.sql | docker compose exec -T postgres psql -U postgres

# Restart services
docker compose start
```

### Full Restore

```bash
# Stop everything
docker compose down

# Remove existing volumes
docker volume rm btcpay_datadir btcpay_plugins postgres_datadir

# Create fresh volumes
docker compose up -d postgres
# Wait for postgres healthy

# Restore postgres
cat backup.sql | docker compose exec -T postgres psql -U postgres

# Restore BTCPay data
docker run --rm \
  -v btcpay_datadir:/data \
  -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/btcpay_data.tar.gz -C /data

# Start all services
docker compose up -d
```

## Updates and Upgrades

### Checking for Updates

```bash
# Check current versions
docker compose exec btcpayserver cat /app/version.txt 2>/dev/null || echo "Check BTCPAY_VERSION in .env"
docker compose exec bitcoind bitcoin-cli --version
docker compose exec postgres psql --version
```

### Update Process

1. **Review release notes** for breaking changes

2. **Backup before update**:
   ```bash
   ./scripts/backup.sh
   ```

3. **Update version in .env**:
   ```bash
   BTCPAY_VERSION=2.1.0
   BITCOIN_VERSION=28.1
   ```

4. **Pull and restart**:
   ```bash
   docker compose pull
   docker compose up -d
   ```

5. **Verify update**:
   ```bash
   make health
   docker compose logs --since 5m
   ```

### Rollback

If update fails:

```bash
# Revert to previous version
BTCPAY_VERSION=2.0.6  # Previous version

# Restart with old version
docker compose up -d

# If data corruption, restore backup
./scripts/restore.sh backup_YYYYMMDD.sql
```

## Scaling and Performance

### Bitcoin Core Optimization

For faster sync:
```bash
# Increase cache (requires more RAM)
BITCOIN_DBCACHE=2048  # 2GB

# Increase connections
BITCOIN_EXTRA_ARGS: |
  maxconnections=125
  dbcache=${BITCOIN_DBCACHE:-512}
```

### PostgreSQL Tuning

For high transaction volume:
```bash
POSTGRES_MAX_CONNECTIONS=500
POSTGRES_SHARED_BUFFERS=512MB
POSTGRES_EFFECTIVE_CACHE=2GB
```

Add to postgres command:
```yaml
command:
  - "-c"
  - "work_mem=64MB"
  - "-c"
  - "maintenance_work_mem=256MB"
```

### Resource Allocation

Recommended minimums:

| Scenario | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Mainnet full | 16GB | 4 cores | 1TB SSD |
| Mainnet pruned | 4GB | 2 cores | 50GB SSD |
| Testnet | 4GB | 2 cores | 100GB SSD |
| Regtest | 2GB | 1 core | 10GB |

## Security Operations

### Credential Rotation

1. **Generate new passwords**

2. **Update PostgreSQL**:
   ```bash
   docker compose exec postgres psql -U postgres \
     -c "ALTER USER postgres PASSWORD 'new_password';"
   ```

3. **Update .env** with new values

4. **Restart services**:
   ```bash
   docker compose up -d
   ```

### Security Audit Checklist

- [ ] No default passwords in production
- [ ] HTTPS enforced (via proxy)
- [ ] Bitcoin RPC not exposed externally
- [ ] PostgreSQL not exposed externally
- [ ] Regular backups tested
- [ ] Container images from trusted sources
- [ ] Firewall rules configured

### Access Logs

```bash
# BTCPay access patterns
docker compose logs btcpayserver | grep -E "HTTP|auth"

# Bitcoin RPC calls
docker compose logs bitcoind | grep "RPC"
```

## Disaster Recovery

### Scenario: Complete Server Loss

1. Provision new server with Docker
2. Deploy docker-server-blockchain
3. Restore PostgreSQL backup
4. Restore BTCPay data volumes
5. Bitcoin Core will resync automatically (takes days)

### Scenario: Corrupted Bitcoin Data

```bash
# Reset Bitcoin only
docker compose stop bitcoind nbxplorer btcpayserver
docker volume rm bitcoin_datadir
docker compose up -d

# Wait for resync (days for mainnet)
```

### Scenario: Database Corruption

```bash
# Reset PostgreSQL only
docker compose stop btcpayserver nbxplorer
docker volume rm postgres_datadir
docker compose up -d postgres

# Restore from backup
cat latest_backup.sql | docker compose exec -T postgres psql -U postgres

# Restart services
docker compose up -d
```

## Maintenance Windows

### Planned Downtime

```bash
# Announce maintenance
# ...

# Create pre-maintenance backup
./scripts/backup.sh

# Stop services
docker compose down

# Perform maintenance
# ...

# Start services
docker compose up -d

# Verify health
make health
```

### Zero-Downtime Updates (Advanced)

For critical deployments, consider:
- Blue-green deployment
- Rolling updates
- Load balancer health checks

This requires additional infrastructure beyond this repository.

## Monitoring Integration

### Prometheus Metrics

BTCPay Server exposes metrics at `/metrics` (requires configuration).

### Health Check Endpoint

```bash
# BTCPay health
curl -f http://localhost:49392/

# NBXplorer health
curl -f http://localhost:32838/health

# Bitcoin via RPC
bitcoin-cli getblockchaininfo
```

### Alert Triggers

Recommended alerts:
- Container unhealthy > 5 minutes
- Disk usage > 80%
- Memory usage > 90%
- Bitcoin sync < 99%
- PostgreSQL connection failures
