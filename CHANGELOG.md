# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2025-12-26

### Added

- All-in-One (AIO) Docker image for simplified deployments
- Supervisor-based multi-process management in AIO image
- Single `/data` volume mount for NAS compatibility
- Core Lightning (CLN) compose addon (`docker-compose.lightning.yml`)
- LND compose addon (`docker-compose.lnd.yml`)
- RTL web interface for CLN management
- ThunderHub web interface for LND management
- Comprehensive test suite for AIO image
- CI/CD workflows for AIO build and publish
- Weekly security rebuild workflow with Trivy scanning
- AIO deployment documentation (`docs/AIO.md`)
- Lightning setup guide (`docs/LIGHTNING.md`)
- Planning documentation (`doc/EPICS.md`, `doc/TASKS.md`)

### Changed

- Updated README with AIO and Lightning sections
- Improved documentation structure

## [1.0.0] - 2024-12-24

### Added

- Initial release
- BTCPay Server deployment (v2.0.6)
- Bitcoin Core full node support (v28.0)
- NBXplorer blockchain indexer (v2.5.16)
- PostgreSQL database backend (v16)
- Coolify-optimized compose file with magic environment variables
- Development configuration with regtest network
- Multi-network support (mainnet, testnet, signet, regtest)
- Health checks for all services
- Comprehensive environment variable configuration
- Makefile with common operations
- Documentation (README, CONTRIBUTING, SECURITY)
- EUPL-1.2 license
