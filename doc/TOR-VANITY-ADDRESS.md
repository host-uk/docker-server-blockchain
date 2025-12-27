# Tor Vanity Onion Address Generation

## Overview

Tor v3 onion addresses are 56 characters long and look like:
```
duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion
```

You can generate a "vanity" address with a custom prefix (e.g., `btcpay...`) using brute-force key generation.

## Tools

### mkp224o (Recommended)

The fastest tool for generating v3 onion vanity addresses.

#### Install on macOS
```bash
brew install mkp224o
```

#### Install on Linux (Debian/Ubuntu)
```bash
sudo apt-get install gcc libsodium-dev make autoconf
git clone https://github.com/cathugger/mkp224o.git
cd mkp224o
./autogen.sh
./configure
make
```

#### Generate a Vanity Address
```bash
# Generate address starting with "btcpay"
mkp224o btcpay -d ./vanity-keys -n 1

# Generate address starting with "pay" (faster, shorter prefix)
mkp224o pay -d ./vanity-keys -n 1

# Generate with multiple prefixes
mkp224o btcpay pay host -d ./vanity-keys -n 3
```

**Time estimates** (on modern CPU):
| Prefix Length | Approximate Time |
|---------------|------------------|
| 1 char        | Instant          |
| 2 chars       | < 1 second       |
| 3 chars       | < 1 minute       |
| 4 chars       | ~5 minutes       |
| 5 chars       | ~3 hours         |
| 6 chars       | ~4 days          |
| 7 chars       | ~5 months        |
| 8 chars       | ~13 years        |

#### Output Files
mkp224o creates a directory with:
```
vanity-keys/
└── btcpayxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.onion/
    ├── hostname              # Your .onion address
    ├── hs_ed25519_public_key # Public key
    └── hs_ed25519_secret_key # Private key (KEEP SECRET!)
```

## Using Your Vanity Address with BTCPay

### Method 1: Copy Keys to Docker Volume

```bash
# Find your generated keys
ls ./vanity-keys/

# Copy to the tor_keys volume location
docker volume inspect tor_keys  # Find the mountpoint
sudo cp ./vanity-keys/btcpay*.onion/* /var/lib/docker/volumes/tor_keys/_data/

# Set correct permissions
sudo chown -R 100:101 /var/lib/docker/volumes/tor_keys/_data/
sudo chmod 600 /var/lib/docker/volumes/tor_keys/_data/hs_ed25519_secret_key

# Restart the Tor container
docker compose restart tor
```

### Method 2: Mount Keys Directory

Update `docker-compose.yaml`:
```yaml
tor:
  volumes:
    - ./my-vanity-keys:/var/lib/tor/hidden_service/
    - tor_data:/var/lib/tor/
```

## Verify Your Onion Address

After starting the Tor service:
```bash
# Check the generated/loaded onion address
docker exec -it docker-server-blockchain-tor-1 cat /var/lib/tor/hidden_service/hostname

# Check Tor logs
docker logs docker-server-blockchain-tor-1
```

## Access BTCPay via Tor

1. Install Tor Browser: https://www.torproject.org/download/
2. Navigate to your .onion address
3. The connection is end-to-end encrypted and anonymous

## Security Notes

- **NEVER share your `hs_ed25519_secret_key`** - this is your private key
- Back up your keys securely - losing them means losing your .onion address
- Vanity addresses don't reduce security, only the search time increases
- Consider using a dedicated machine for key generation to avoid side-channel attacks

## Alternative Tools

### Eschalot (Legacy, v2 only)
Only works for deprecated v2 addresses. Not recommended.

### Shallot (Legacy, v2 only)
Only works for deprecated v2 addresses. Not recommended.

### vanity-onion-rs (Rust)
```bash
cargo install vanity-onion
vanity-onion btcpay
```

## References

- [mkp224o GitHub](https://github.com/cathugger/mkp224o)
- [Tor Project - Onion Services](https://community.torproject.org/onion-services/)
- [BTCPay Server Tor Documentation](https://docs.btcpayserver.org/Docker/networking/#tor)
