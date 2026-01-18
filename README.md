# Node.js image with Python, Git, jq, and yq

This Dockerfile uses a multi-stage build process to create a lightweight image with Node.js, Git, jq, yq, and Python, supporting both arm64 and x86_64 architectures.

## Stages

### Tools Builder Stage
- Downloads pre-built jq and yq binaries from GitHub releases.
- Supports both amd64 and arm64 architectures.

### Python Builder Stage
- Downloads pre-built Python binaries from [python-build-standalone](https://github.com/astral-sh/python-build-standalone).
- Uses PGO+LTO optimized builds for better performance.
- Supports both x86_64 and aarch64 architectures.

### Node.js Builder Stage
- Downloads pre-built Node.js binaries from nodejs.org.
- Supports both linux-x64 and linux-arm64 architectures.

### Bundle Stage
- Collects all built artifacts into a single scratch image.
- Copies Node.js, Python, jq, and yq binaries to their final locations.

### Final Image
- Based on debian:bookworm-slim.
- Copies all tools from the bundle stage.
- Installs Git from Debian sid (latest version, pinned safely).
- Creates symlinks for Python (python, python3).
- Installs runtime dependencies.
- Installs pnpm, pm2, and node-gyp globally.

## Usage

### Tools included

| Tool     | Description                                      |
|----------|--------------------------------------------------|
| Git      | Version control system (from sid)                |
| jq       | JSON processor (pre-built binary)                |
| yq       | YAML/JSON/XML processor (pre-built binary)       |
| Python   | Programming language (pre-built binary)          |
| Node.js  | JavaScript runtime (pre-built binary)            |
| npm      | Node.js package manager                          |
| yarn     | Alternative package manager                      |
| pnpm     | Fast, disk space-efficient package manager       |
| pm2      | Process manager for Node.js applications         |
| node-gyp | Tool for compiling native addon modules          |

## Version Overview

| Tool/Dependency | Version       | Source                        |
|-----------------|---------------|-------------------------------|
| Node.js         | 24.13.0       | nodejs.org binary             |
| Python          | 3.13.11       | python-build-standalone       |
| Git             | latest        | Debian sid (pinned)           |
| jq              | 1.8.1         | GitHub releases               |
| yq              | 4.50.1        | GitHub releases               |
| pm2             | 6.0.14        | npm                           |
| node-gyp        | 12.1.0        | npm                           |
| pnpm            | 10.28.0       | GitHub release (static)       |
| Debian Base     | bookworm-slim | Base OS                       |

### Runtime dependencies (final image)

| Package         | Description                                |
|-----------------|--------------------------------------------|
| curl            | Data transfer tool                         |
| wget            | Network downloader                         |
| ca-certificates | Common CA certificates                     |
| fontconfig      | Font configuration library                 |
| binutils        | GNU binary utilities                       |
| dumb-init       | Simple init system for containers          |
| bash            | GNU Bourne Again SHell                     |
| openssl         | SSL toolkit                                |
| libc6           | GNU C Library                              |
| libcurl4        | URL transfer library                       |
| libgcc-s1       | GCC support library                        |

## Building

```bash
docker build -t nodejs-git-jq-python-tools .
```

## Multi-architecture builds

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t nodejs-git-jq-python-tools .
```
