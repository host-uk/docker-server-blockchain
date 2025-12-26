# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public issue
2. Email security concerns to the maintainers
3. Include detailed reproduction steps
4. Allow reasonable time for a fix before public disclosure

## Security Best Practices

### Production Deployment

1. **Change default credentials**
   - Set strong `POSTGRES_PASSWORD`
   - Change `BITCOIN_RPC_USER` and `BITCOIN_RPC_PASSWORD`

2. **Network security**
   - Use a reverse proxy with TLS (handled by Coolify)
   - Restrict Bitcoin RPC access to internal network
   - Consider firewall rules for P2P ports

3. **Data protection**
   - Regular backups of PostgreSQL and BTCPay data
   - Secure backup storage
   - Test recovery procedures

4. **Updates**
   - Keep all container images updated
   - Monitor BTCPay Server security advisories
   - Subscribe to Bitcoin Core security announcements

### Credentials Management

- Never commit `.env` files with real credentials
- Use Coolify's secret management for sensitive values
- Rotate credentials periodically

### Container Security

- Images are pulled from official sources
- Containers run with minimal privileges
- Health checks ensure service availability

## Known Security Considerations

1. **Bitcoin RPC**: By default, RPC is accessible within the Docker network. Do not expose externally.

2. **PostgreSQL**: Uses `scram-sha-256` authentication in production. Development mode uses `trust` for convenience.

3. **BTCPay Server**: Ensure HTTPS is configured via reverse proxy before accepting real payments.

## Dependencies

This project relies on upstream security practices from:

- [BTCPay Server](https://github.com/btcpayserver/btcpayserver)
- [Bitcoin Core](https://github.com/bitcoin/bitcoin)
- [NBXplorer](https://github.com/dgarage/NBXplorer)
- [PostgreSQL](https://www.postgresql.org/support/security/)
