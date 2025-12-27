# Security & Code Quality Review

Generated: 2025-12-27

## Critical Issues (6)

### 1. Hardcoded Weak Credentials in `.env` File
- **File:** `.env`
- **Issue:** Weak default passwords (rpcpassword, your_secure_password_here)
- **Fix:** Remove `.env` from git, generate strong passwords

### 2. Credentials File Written with World-Readable Permissions
- **File:** `scripts/aio-entrypoint.sh:645`
- **Issue:** Brief window where credentials readable before chmod 600
- **Fix:** Use `(umask 077 && cat > "$creds_file" ...)`

### 3. Missing Error Handling in Health Check Script
- **File:** `scripts/health-check.sh`
- **Issue:** No validation of required environment variables
- **Fix:** Add `: "${VAR:?must be set}"` checks

### 4. PostgreSQL Trust Authentication
- **File:** `scripts/aio-entrypoint.sh:196-200`
- **Issue:** `pg_hba.conf` uses trust for local connections
- **Fix:** Use peer/scram-sha-256 authentication

### 5. MariaDB Root Without Password
- **File:** `scripts/aio-entrypoint.sh:274-279`
- **Issue:** Root user created without password
- **Fix:** Set root password during initialization

### 6. Mempool Hardcoded Credentials
- **File:** `scripts/aio-entrypoint.sh:276-277`
- **Issue:** mempool:mempool credentials
- **Fix:** Generate random password like other services

## Important Issues (9)

### 7. Missing TARGETARCH Validation
- **File:** `Dockerfile:178-184`

### 8. Bitcoin RPC Password in Process List
- **File:** `scripts/health-check.sh:17-24`
- **Fix:** Use bitcoin.conf authentication

### 9. No Binary Signature Verification
- **File:** `Dockerfile:202-206, 217-224`
- **Fix:** Verify GPG signatures for Bitcoin Core and Monero

### 10. Missing TLS/HTTPS Configuration
- **File:** `config/nginx/nginx.conf`
- **Fix:** Add SSL server block with Let's Encrypt

### 11. Missing Security Headers
- **File:** `config/nginx/nginx.conf:52-55`
- **Fix:** Add CSP, HSTS, Referrer-Policy

### 12. Backup Without Stopping Writes
- **File:** `scripts/backup.sh:121-125`

### 13. No Resource Limits
- **Files:** All supervisor configs

### 14. Container Runs as Root
- **File:** `Dockerfile:321-322`

### 15. NBXplorer noauth=1
- **File:** `scripts/aio-entrypoint.sh:486`

## Top 3 Immediate Actions

1. Remove `.env` from git and enforce strong passwords
2. Add TLS/HTTPS configuration to nginx
3. Implement binary signature verification for Bitcoin Core and Monero
