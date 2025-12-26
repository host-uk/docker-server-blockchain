# BTCPay Server Docker Stack - Task Tracker

## Current Sprint

### In Progress
- [ ] Create AIO deployment documentation
- [ ] Create Lightning setup documentation

### Completed This Sprint
- [x] Create all-in-one Dockerfile
- [x] Create supervisor configurations
- [x] Create AIO entrypoint script
- [x] Create test suite for AIO image
- [x] Create CI/CD workflows for AIO
- [x] Add Core Lightning (CLN) compose addon
- [x] Add LND compose addon

---

## Backlog

### High Priority
- [ ] Add Prometheus metrics endpoint to AIO image
- [ ] Create Grafana dashboard template
- [ ] Add Let's Encrypt auto-renewal for non-Coolify deployments
- [ ] Create migration guide from docker-compose to AIO

### Medium Priority
- [ ] Add optional Tor support
- [ ] Create backup automation with retention policies
- [ ] Add PostgreSQL replication support
- [ ] Create disaster recovery documentation

### Low Priority
- [ ] Add ARM32 build support
- [ ] Create Kubernetes Helm chart
- [ ] Add OpenTelemetry tracing
- [ ] Create performance tuning guide

---

## Completed Tasks

### v1.1.0 - AIO Release
- [x] Dockerfile - All-in-one multi-stage build
- [x] config/supervisor/supervisord.conf
- [x] config/supervisor/services/postgres.conf
- [x] config/supervisor/services/bitcoind.conf
- [x] config/supervisor/services/nbxplorer.conf
- [x] config/supervisor/services/btcpayserver.conf
- [x] scripts/aio-entrypoint.sh
- [x] tests/lib.sh
- [x] tests/test-build.sh
- [x] tests/test-services.sh
- [x] tests/test-config.sh
- [x] tests/run-all.sh
- [x] .github/workflows/build-aio.yml
- [x] .github/workflows/publish-aio.yml
- [x] .github/workflows/weekly.yml
- [x] docker-compose.lightning.yml (CLN)
- [x] docker-compose.lnd.yml

### v1.0.0 - Initial Release
- [x] docker-compose.yaml
- [x] docker-compose.dev.yml
- [x] docker-compose.coolify.yaml
- [x] .env.example
- [x] Makefile
- [x] scripts/entrypoint.sh
- [x] scripts/backup.sh
- [x] scripts/health-check.sh
- [x] docs/ARCHITECTURE.md
- [x] docs/CONFIGURATION.md
- [x] docs/COOLIFY.md
- [x] docs/TROUBLESHOOTING.md
- [x] docs/OPERATIONS.md
- [x] .github/workflows/validate.yml
- [x] README.md
- [x] CONTRIBUTING.md
- [x] SECURITY.md
- [x] LICENCE
- [x] CHANGELOG.md

---

## Notes

### AIO Image Design Decisions
1. **Supervisor over s6-overlay**: Simpler configuration, widely understood
2. **Single /data volume**: Easy NAS mounting, single backup target
3. **Environment-based config**: Works with Coolify magic variables
4. **No txindex by default**: Allows pruning for space efficiency

### Lightning Implementation Choice
- **CLN**: Better for advanced users, more flexible, smaller footprint
- **LND**: Better UI ecosystem (ThunderHub), more widely used

### Testing Strategy
- Build tests: Verify image structure without running services
- Config tests: Verify initialization created correct configs
- Service tests: Full integration tests with running services
