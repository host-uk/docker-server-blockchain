# ============================================================
# Docker Server Blockchain - Makefile
# ============================================================

.PHONY: help dev up down restart logs ps shell clean \
        bitcoin-cli btcpay-cli nbxplorer-cli psql \
        backup restore aio-build aio-run aio-test \
        lightning lnd

# Default target
.DEFAULT_GOAL := help

# Variables
COMPOSE := docker compose
COMPOSE_DEV := $(COMPOSE) -f docker-compose.yaml -f docker-compose.dev.yml
COMPOSE_PROD := $(COMPOSE) -f docker-compose.yaml
COMPOSE_CLN := $(COMPOSE) -f docker-compose.yaml -f docker-compose.lightning.yml
COMPOSE_LND := $(COMPOSE) -f docker-compose.yaml -f docker-compose.lnd.yml
AIO_IMAGE := btcpay-aio

# ============================================================
# Help
# ============================================================

help: ## Show this help message
	@echo "Docker Server Blockchain - Available Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

# ============================================================
# Development
# ============================================================

dev: ## Start development environment (regtest)
	$(COMPOSE_DEV) up -d
	@echo ""
	@echo "BTCPay Server: http://localhost:49392"
	@echo "NBXplorer:     http://localhost:32838"
	@echo "Bitcoin RPC:   http://localhost:43782"
	@echo "PostgreSQL:    localhost:5432"

dev-build: ## Build and start development environment
	$(COMPOSE_DEV) up -d --build

dev-logs: ## Follow development logs
	$(COMPOSE_DEV) logs -f

# ============================================================
# Production
# ============================================================

up: ## Start production environment
	$(COMPOSE_PROD) up -d

up-build: ## Build and start production environment
	$(COMPOSE_PROD) up -d --build

# ============================================================
# Common Operations
# ============================================================

down: ## Stop all services
	$(COMPOSE_PROD) down

restart: ## Restart all services
	$(COMPOSE_PROD) restart

logs: ## Follow all logs
	$(COMPOSE_PROD) logs -f

logs-btcpay: ## Follow BTCPay Server logs
	$(COMPOSE_PROD) logs -f btcpayserver

logs-bitcoin: ## Follow Bitcoin Core logs
	$(COMPOSE_PROD) logs -f bitcoind

logs-nbx: ## Follow NBXplorer logs
	$(COMPOSE_PROD) logs -f nbxplorer

logs-postgres: ## Follow PostgreSQL logs
	$(COMPOSE_PROD) logs -f postgres

ps: ## Show running services
	$(COMPOSE_PROD) ps

# ============================================================
# Shell Access
# ============================================================

shell: ## Shell into BTCPay Server container
	$(COMPOSE_PROD) exec btcpayserver /bin/bash

shell-bitcoin: ## Shell into Bitcoin Core container
	$(COMPOSE_PROD) exec bitcoind /bin/bash

shell-nbx: ## Shell into NBXplorer container
	$(COMPOSE_PROD) exec nbxplorer /bin/bash

shell-postgres: ## Shell into PostgreSQL container
	$(COMPOSE_PROD) exec postgres /bin/bash

# ============================================================
# CLI Tools
# ============================================================

bitcoin-cli: ## Access bitcoin-cli (usage: make bitcoin-cli ARGS="getblockchaininfo")
	$(COMPOSE_PROD) exec bitcoind bitcoin-cli \
		-rpcuser=$${BITCOIN_RPC_USER:-rpc} \
		-rpcpassword=$${BITCOIN_RPC_PASSWORD:-rpcpassword} \
		$(ARGS)

psql: ## Access PostgreSQL CLI
	$(COMPOSE_PROD) exec postgres psql -U postgres

# ============================================================
# Bitcoin Operations
# ============================================================

blockchain-info: ## Get blockchain info
	@make bitcoin-cli ARGS="getblockchaininfo"

network-info: ## Get network info
	@make bitcoin-cli ARGS="getnetworkinfo"

mempool-info: ## Get mempool info
	@make bitcoin-cli ARGS="getmempoolinfo"

# Development: Generate blocks (regtest only)
generate: ## Generate blocks in regtest (usage: make generate N=10)
	$(COMPOSE_DEV) exec bitcoind bitcoin-cli \
		-rpcuser=$${BITCOIN_RPC_USER:-rpc} \
		-rpcpassword=$${BITCOIN_RPC_PASSWORD:-rpcpassword} \
		-generate $(N)

# ============================================================
# Health Checks
# ============================================================

health: ## Check health of all services
	@echo "Service Health Status:"
	@echo "====================="
	@$(COMPOSE_PROD) ps --format "table {{.Name}}\t{{.Status}}"

# ============================================================
# Cleanup
# ============================================================

clean: ## Stop and remove all containers and volumes (DESTRUCTIVE)
	@echo "WARNING: This will remove all data!"
	@read -p "Are you sure? [y/N] " confirm && \
		[ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] && \
		$(COMPOSE_PROD) down -v --remove-orphans

clean-dev: ## Stop and remove development environment
	$(COMPOSE_DEV) down -v --remove-orphans

prune: ## Remove unused Docker resources
	docker system prune -f

# ============================================================
# Backup & Restore
# ============================================================

backup: ## Create backup of all volumes
	@mkdir -p backups
	@echo "Backing up PostgreSQL..."
	$(COMPOSE_PROD) exec -T postgres pg_dumpall -U postgres > backups/postgres_$$(date +%Y%m%d_%H%M%S).sql
	@echo "Backup complete: backups/postgres_$$(date +%Y%m%d_%H%M%S).sql"

backup-btcpay: ## Backup BTCPay data volume
	@mkdir -p backups
	docker run --rm -v btcpay_datadir:/data -v $$(pwd)/backups:/backup \
		alpine tar czf /backup/btcpay_$$(date +%Y%m%d_%H%M%S).tar.gz -C /data .

# ============================================================
# Updates
# ============================================================

pull: ## Pull latest images
	$(COMPOSE_PROD) pull

update: pull up ## Pull latest images and restart

# ============================================================
# Development Utilities
# ============================================================

env: ## Create .env from .env.example
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "Created .env from .env.example"; \
	else \
		echo ".env already exists"; \
	fi

validate: ## Validate docker-compose files
	$(COMPOSE_PROD) config --quiet && echo "Production compose: OK"
	$(COMPOSE_DEV) config --quiet && echo "Development compose: OK"
	$(COMPOSE_CLN) config --quiet && echo "Lightning (CLN) compose: OK"
	$(COMPOSE_LND) config --quiet && echo "Lightning (LND) compose: OK"

# ============================================================
# All-in-One (AIO) Image
# ============================================================

aio-build: ## Build the AIO Docker image
	docker build -t $(AIO_IMAGE) .

aio-run: ## Run the AIO image (regtest, for testing)
	docker run -d --name btcpay-aio \
		-p 49392:49392 \
		-e BTCPAY_NETWORK=regtest \
		-e BTCPAY_HOST=localhost \
		-v btcpay-aio-data:/data \
		$(AIO_IMAGE)
	@echo ""
	@echo "BTCPay Server AIO running at http://localhost:49392"
	@echo "View logs: docker logs -f btcpay-aio"

aio-stop: ## Stop and remove AIO container
	docker stop btcpay-aio 2>/dev/null || true
	docker rm btcpay-aio 2>/dev/null || true

aio-test: aio-build ## Build and run tests on AIO image
	docker run --rm $(AIO_IMAGE) /bin/sh -c "chmod +x /tests/*.sh 2>/dev/null; sh /tests/run-all.sh build"

aio-shell: ## Shell into running AIO container
	docker exec -it btcpay-aio /bin/bash

aio-logs: ## Follow AIO container logs
	docker logs -f btcpay-aio

aio-status: ## Check AIO service status
	docker exec btcpay-aio supervisorctl status

# ============================================================
# Lightning Network
# ============================================================

lightning: ## Start with Core Lightning (CLN)
	$(COMPOSE_CLN) up -d
	@echo ""
	@echo "BTCPay + Lightning (CLN) started"
	@echo "RTL available on port 3000"

lnd: ## Start with LND
	$(COMPOSE_LND) up -d
	@echo ""
	@echo "BTCPay + Lightning (LND) started"
	@echo "ThunderHub available on port 3000"

lightning-down: ## Stop Lightning setup (CLN)
	$(COMPOSE_CLN) down

lnd-down: ## Stop LND setup
	$(COMPOSE_LND) down

lightning-cli: ## Access lightning-cli (CLN)
	$(COMPOSE_CLN) exec clightning lightning-cli $(ARGS)

lncli: ## Access lncli (LND)
	$(COMPOSE_LND) exec lnd lncli --network=$${BTCPAY_NETWORK:-mainnet} $(ARGS)
