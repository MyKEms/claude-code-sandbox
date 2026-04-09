# Security

This project creates sandboxed environments for AI coding agents using Docker network isolation and a Squid proxy allowlist.

## Reporting Issues

Found a vulnerability (proxy bypass, container escape, credential leak)? Open a [GitHub issue](https://github.com/MyKEms/claude-code-sandbox/issues). If it's sensitive, mark it as confidential in the description.

## What This Secures

- Network isolation - workspace has no direct internet
- Allowlist-only egress via Squid proxy
- Credentials injected as env vars, never baked into images
- SSH keys stay on host, only agent socket is mounted

## Known Limitations

- **Workspace files** - the agent has full read/write access to `/workspace`
- **Allowlisted domains** - traffic to allowed domains is not inspected beyond the domain check
- **Docker itself** - if Docker has a vulnerability, the sandbox can be bypassed
- **Host Docker socket** - don't mount it into the container
