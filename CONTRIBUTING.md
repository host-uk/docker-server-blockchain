# Contributing to Docker Server Blockchain

Thank you for your interest in contributing to Docker Server Blockchain! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## How to Contribute

### Reporting Issues

1. Check existing issues to avoid duplicates
2. Use the issue template if available
3. Provide clear reproduction steps
4. Include relevant logs and environment details

### Pull Requests

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Test thoroughly with both development and production configurations
5. Submit a pull request

### Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/docker-server-blockchain.git
cd docker-server-blockchain

# Copy environment file
cp .env.example .env

# Start development environment
make dev

# Access BTCPay Server at http://localhost:49392
```

### Testing

Before submitting a PR, verify:

1. **Development mode works**: `make dev`
2. **Production mode works**: `make up`
3. **All services start**: `make ps`
4. **Health checks pass**: Check container health status
5. **Coolify compose validates**: Test with Coolify if possible

### Commit Messages

Use clear, descriptive commit messages:

```
feat: add Lightning Network support for LND
fix: resolve PostgreSQL connection timeout
docs: update Coolify deployment instructions
chore: update Bitcoin Core to v28.0
```

### Code Style

- Use consistent YAML formatting
- Document environment variables in `.env.example`
- Update README for user-facing changes
- Include comments for complex configurations

## Areas for Contribution

- Lightning Network integration (LND, Core Lightning)
- Additional cryptocurrency support
- Performance optimizations
- Documentation improvements
- CI/CD workflows
- Security enhancements

## Questions?

Open an issue for questions or join discussions in existing issues.
