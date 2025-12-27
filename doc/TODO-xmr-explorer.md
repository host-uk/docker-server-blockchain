# TODO: XMR Explorer - Full Monero Integration

## Current State
- Basic XMR Explorer frontend (DiedB/Monero-Blockchain-Explorer) working at `/explorer/xmr/`
- API runs on port 3001 but proxies to external `onion.bct.diederik.it` service
- No direct integration with local monerod

## Goal
Replace proxy-based explorer with a proper Monero block explorer that talks directly to local monerod RPC.

## Options Explored

### 1. onion-monero-blockchain-explorer (C++)
- **Repo**: https://github.com/moneroexamples/onion-monero-blockchain-explorer
- **Blocker**: Requires pre-built Monero libraries (libmonero-cpp, etc.)
- **Effort**: High - need to compile Monero from source first

### 2. lthn/explorer (NestJS)
- **Image**: docker.io/lthn/explorer:latest
- **Issue**: Designed for Lethean (LTHN), proxies to explorer.lethean.io
- **Potential**: Could be forked/adapted to use monerod JSON-RPC directly

### 3. lthn/build images
- `lthn/build:compile` - Ubuntu with cmake, gcc, make
- `lthn/build:libs-x86_64-unknown-linux-gnu` - Pre-built Lethean/Monero libs
- **Note**: Builder images with custom entrypoints, designed for CI pipelines

## Recommended Approach

### Option A: Build onion-monero-blockchain-explorer
```dockerfile
FROM lthn/build:compile AS xmr-explorer-build

# Install deps
RUN apt-get update && apt-get install -y \
    libunbound-dev libboost-all-dev libssl-dev \
    libzmq3-dev libsodium-dev git

# Clone and build Monero first (provides libs)
RUN git clone --recursive --depth 1 https://github.com/monero-project/monero.git /monero
WORKDIR /monero
RUN make release-static -j$(nproc)

# Then build explorer with MONERO_SOURCE_DIR=/monero
WORKDIR /src
RUN git clone https://github.com/moneroexamples/onion-monero-blockchain-explorer.git .
RUN mkdir build && cd build && \
    cmake -DMONERO_SOURCE_DIR=/monero .. && \
    make -j$(nproc)
```

### Option B: Write minimal monerod RPC client
- Keep current React frontend
- Replace Node.js API to call monerod JSON-RPC directly:
  - `get_block_count`
  - `get_block`
  - `get_transactions`
  - `get_info`

## monerod RPC Endpoints
```
http://127.0.0.1:18081/json_rpc  (restricted RPC)
http://127.0.0.1:18082/json_rpc  (full RPC, if enabled)
```

## Files to Modify
- `xmr-explorer/api/api.js` - Replace external proxy with monerod RPC calls
- `config/supervisor/services/monerod.conf` - Ensure `--rpc-bind-ip=127.0.0.1`
- `scripts/aio-entrypoint.sh` - Add monerod RPC config

## Resources
- monerod RPC: https://www.getmonero.org/resources/developer-guides/daemon-rpc.html
- lthn/build: https://github.com/letheanVPN/lthn-app-build
- onion-monero-blockchain-explorer: https://github.com/moneroexamples/onion-monero-blockchain-explorer
