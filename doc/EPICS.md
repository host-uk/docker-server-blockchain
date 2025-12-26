# BTCPay Server Docker Stack - Epics

## Overview

This document tracks high-level epics for the BTCPay Server docker deployment stack.

---

## Epic 1: Core BTCPay Stack [COMPLETED]

**Status:** Complete
**Priority:** Critical

Provide a production-ready Docker Compose configuration for BTCPay Server with all required dependencies.

### Features
- [x] BTCPay Server container with proper configuration
- [x] NBXplorer blockchain indexer
- [x] Bitcoin Core full/pruned node
- [x] PostgreSQL database
- [x] Proper health checks
- [x] Volume persistence
- [x] Environment-based configuration

### Deliverables
- `docker-compose.yaml` - Production configuration
- `docker-compose.dev.yml` - Development overrides
- `.env.example` - Configuration template
- `docs/CONFIGURATION.md` - Configuration guide

---

## Epic 2: Coolify Integration [COMPLETED]

**Status:** Complete
**Priority:** High

Enable one-click deployment through Coolify with automatic SSL and domain configuration.

### Features
- [x] Coolify magic variable support (`SERVICE_FQDN_*`, `SERVICE_PASSWORD_*`)
- [x] Automatic SSL termination
- [x] Proper container labeling
- [x] Health check integration

### Deliverables
- `docker-compose.coolify.yaml` - Coolify-optimized configuration
- `docs/COOLIFY.md` - Coolify deployment guide

---

## Epic 3: All-in-One Image [COMPLETED]

**Status:** Complete
**Priority:** High

Create a single Docker image containing all services for simplified deployments and NAS-backed storage.

### Features
- [x] Multi-stage build for optimized image size
- [x] Supervisor process management
- [x] Single volume mount point (`/data`)
- [x] Automatic service initialization
- [x] Network-configurable (mainnet, testnet, regtest, signet)
- [x] Pruning support for limited storage

### Deliverables
- `Dockerfile` - All-in-one image
- `config/supervisor/` - Process configurations
- `scripts/aio-entrypoint.sh` - Initialization script
- `tests/` - Test suite

---

## Epic 4: Lightning Network Support [COMPLETED]

**Status:** Complete
**Priority:** Medium

Add optional Lightning Network support with choice of implementations.

### Features
- [x] Core Lightning (CLN) support
- [x] LND support
- [x] RTL web interface for CLN
- [x] ThunderHub interface for LND
- [x] BTCPay Server Lightning integration

### Deliverables
- `docker-compose.lightning.yml` - CLN addon
- `docker-compose.lnd.yml` - LND addon

---

## Epic 5: CI/CD & Automation [COMPLETED]

**Status:** Complete
**Priority:** High

Automated building, testing, and publishing of Docker images.

### Features
- [x] Build on push to main
- [x] Multi-architecture builds (amd64, arm64)
- [x] Automated testing
- [x] GitHub Container Registry publishing
- [x] Weekly security rebuilds
- [x] Vulnerability scanning (Trivy)

### Deliverables
- `.github/workflows/build-aio.yml` - Build workflow
- `.github/workflows/publish-aio.yml` - Release workflow
- `.github/workflows/weekly.yml` - Security rebuild

---

## Epic 6: Documentation [IN PROGRESS]

**Status:** In Progress
**Priority:** Medium

Comprehensive documentation for all deployment options and configurations.

### Features
- [x] Architecture documentation
- [x] Configuration reference
- [x] Coolify deployment guide
- [x] Troubleshooting guide
- [ ] AIO deployment guide
- [ ] Lightning setup guide

### Deliverables
- `docs/ARCHITECTURE.md`
- `docs/CONFIGURATION.md`
- `docs/COOLIFY.md`
- `docs/TROUBLESHOOTING.md`
- `docs/AIO.md` (pending)
- `docs/LIGHTNING.md` (pending)

---

## Epic 7: Operations [COMPLETE]

**Status:** Complete
**Priority:** Medium

Operational tools for backup, monitoring, and maintenance.

### Features
- [x] Backup scripts
- [x] Health check scripts
- [x] Makefile commands
- [x] Operations guide

### Deliverables
- `scripts/backup.sh`
- `scripts/health-check.sh`
- `Makefile`
- `docs/OPERATIONS.md`

---

## Future Epics

### Epic 8: Monitoring Stack
- Prometheus metrics
- Grafana dashboards
- Alert configuration

### Epic 9: High Availability
- Multi-node PostgreSQL
- Load balancing
- Failover configuration

### Epic 10: Hardware Wallet Support
- BTCPay Vault integration
- Hardware signing server
