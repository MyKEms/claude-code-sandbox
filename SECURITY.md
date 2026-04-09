# Security Policy

## Scope

This project is a **container isolation template** - it creates sandboxed environments for running AI coding agents. The security model relies on Docker network isolation and Squid proxy allowlisting to restrict agent access.

## Reporting a Vulnerability

If you find a security vulnerability in this project (e.g., a way to bypass the proxy allowlist, escape the container network, or leak credentials), please report it responsibly:

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email: **mykems-github@wzk.cz** with subject line `[SECURITY] claude-code-sandbox`
3. Include steps to reproduce and the potential impact
4. I will respond within 7 days

## What This Project Secures

- Network isolation: workspace container has no direct internet access
- Egress control: all outbound traffic passes through an allowlist-only Squid proxy
- Credential isolation: API keys are injected as env vars, never baked into images
- SSH key protection: only the agent socket is mounted, private keys stay on host
- Per-project isolation: each project gets its own containers, volumes, and memory

## What This Project Does NOT Secure

- **Host Docker socket**: if mounted (not default), the agent could escape the container
- **Workspace files**: the agent has full read/write access to `/workspace`
- **Allowlisted domains**: traffic to allowed domains is not inspected or filtered beyond the domain check
- **Container escapes**: this project relies on Docker's isolation - if Docker itself has a vulnerability, the sandbox can be bypassed
- **Side channels**: timing attacks, DNS exfiltration via allowed domains, or steganography in allowed traffic are not mitigated

## Supported Versions

Only the latest version on `main` is supported. There are no versioned releases yet.

## Dependencies

Security-relevant dependencies:
- **Docker** - container runtime (isolation boundary)
- **Squid** - forward proxy (egress control)
- **Claude Code CLI** - AI agent (Anthropic-maintained)
- **Node.js** - runtime for Claude CLI
- **Ubuntu 24.04** - base image

Keep your Docker runtime and base images updated.
