# Container Security Audit Findings

## 1. Base Image and Dependencies

### 1.1. Base Image Vulnerabilities
- **Finding:** The primary runtime image is `debian:bookworm-slim`. While a "slim" image is used, it's essential to regularly scan it for vulnerabilities.
- **Risk:** The base image could have known vulnerabilities (e.g., in system libraries) that could be exploited to compromise the container.
- **Recommendation:** Implement a container scanning tool (e.g., Trivy, Clair) in the CI/CD pipeline to automatically scan `debian:bookworm-slim` for vulnerabilities.

### 1.2. Pinned but Potentially Outdated Dependencies
- **Finding:** Several software versions are pinned in the `Dockerfile`, including:
  - `BITCOIN_VERSION=28.1`
  - `MONERO_VERSION=0.18.4.4`
  - `NBXPLORER_VERSION=2.5.30`
  - `BTCPAY_VERSION=2.3.1`
  - `MEMPOOL_VERSION=3.2.1`
- **Risk:** Pinned versions can become outdated, and new versions often contain critical security patches.
- **Recommendation:** Regularly check for new releases of these key dependencies and have a documented process for updating and testing them.

### 1.3. Use of `latest` Tag
- **Finding:** The `mcr.microsoft.com/dotnet/sdk:8.0-alpine` and `node:20-alpine` images are not pinned to a specific digest.
- **Risk:** This could lead to unpredictable builds if the `8.0-alpine` or `20-alpine` tags are updated with breaking changes or vulnerabilities.
- **Recommendation:** Pin base images to a specific digest (`@sha256:...`) to ensure reproducible and secure builds.

## 2. User and Privilege Management

### 2.1. Lack of a Dedicated Non-Root User
- **Finding:** The `Dockerfile` does not define a dedicated non-root user with the `USER` instruction. While some directories are correctly `chown`ed to system users (`postgres`, `mysql`, `www-data`), the main application process and entrypoint script will run as the `root` user by default.
- **Risk:** Running the container as `root` is a significant security risk. A compromise of the application could grant an attacker root access to the container, allowing them to modify the filesystem, install packages, and potentially escalate their privileges to the host.
- **Recommendation:** Create a dedicated non-root user and group in the `Dockerfile`. `chown` the application files to this user, and switch to this user with the `USER` instruction before the `ENTRYPOINT` or `CMD`.

## 3. Secret Handling

### 3.1. Secrets Exposed as Environment Variables
- **Finding:** The `docker-compose.yaml` file injects secrets (`POSTGRES_PASSWORD`, `BITCOIN_RPC_PASSWORD`, etc.) into the container as environment variables.
- **Risk:** Environment variables are not a secure way to handle secrets. They can be easily inspected by running `docker inspect`, and any child processes or linked containers could potentially access them.
- **Recommendation:** Use a more secure secret management solution like Docker Secrets. This will mount secrets as files in `/run/secrets`, providing a more secure and isolated way to handle sensitive information.

### 3.2. Hardcoded Credentials in Development
- **Finding:** The `docker-compose.dev.yml` file contains hardcoded, weak credentials (e.g., `POSTGRES_PASSWORD: devpassword`).
- **Risk:** While this is a development environment, hardcoded credentials can encourage poor security practices and might be accidentally deployed to production.
- **Recommendation:** Even in development, use a mechanism like `.env` files to externalize secrets and ensure they are not checked into version control.

## 4. Network Configuration

### 4.1. Overly Permissive Port Exposure
- **Finding:** The `docker-compose.yaml` file exposes several ports to the host, including P2P ports for Bitcoin (`8333`), Litecoin (`9333`), and Monero (`18080`), as well as the BTCPay Server port (`49392`).
- **Risk:** Exposing ports directly increases the container's attack surface. While the P2P ports are necessary for the nodes to function, the BTCPay Server port should ideally be fronted by a reverse proxy.
- **Recommendation:** Use a reverse proxy (like the included Nginx service) to manage all inbound traffic. This allows for centralized logging, rate limiting, and SSL termination. The BTCPay Server port should only be exposed to the reverse proxy network, not to the host.

### 4.2. Insecure RPC Configuration in Development
- **Finding:** The `docker-compose.dev.yml` file configures the Bitcoin RPC port to be accessible from any IP address (`rpcallowip=0.0.0.0/0`).
- **Risk:** In a development environment, this could allow other machines on the same network to access the Bitcoin RPC, which is a security risk.
- **Recommendation:** Bind the RPC port to `127.0.0.1` or the Docker internal network to restrict access.

## 5. Volume and Filesystem Permissions

### 5.1. Host Directory Permissions
- **Finding:** The `docker-compose.yaml` file mounts host directories (`/data/btcpay` and `/drive/chain-data`) into the container. The security of these mounts depends on the permissions of the host directories.
- **Risk:** If the host directories are overly permissive, a container compromise could lead to a host compromise. For example, if the `/data/btcpay` directory is world-writable, an attacker could modify sensitive configuration files.
- **Recommendation:** Ensure that the host directories used for volumes have strict permissions. They should be owned by a dedicated user and group, and not be readable or writable by other users.

### 5.2. In-Container File Permissions
- **Finding:** The `Dockerfile` creates a number of directories but does not explicitly set restrictive permissions on all of them. While some directories are correctly `chown`ed to system users, a more comprehensive review is needed.
- **Risk:** Incorrect in-container permissions could allow for privilege escalation if a process is compromised.
- **Recommendation:** After creating a non-root user, ensure that all application files and directories are owned by that user. Files that should not be modified at runtime should have their permissions set to read-only.
