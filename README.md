# Node.js image with Python, Git, and jq

This Dockerfile uses a multi-stage build process to create a lightweight image with Node.js, Git, jq, and Python, supporting both arm64 and x86_64 architectures.

## Stages

### Git Builder Stage
- Starts with debian:bookworm-slim as a base for building Git.
- Installs the necessary dependencies for building Git using apt-get.
- Downloads the Git source code for the specified version and builds it from source.
- After Git is built and installed, symlinks are created for Git commands.

### jq Builder Stage
- Builds jq, a lightweight and flexible command-line JSON processor.
- Uses the same debian:bookworm-slim base image.
- Installs build tools and dependencies needed to compile jq from source.
- The jq source code is cloned from its official repository and built with static linking.

### Python Builder Stage
- Downloads pre-built Python binaries from [python-build-standalone](https://github.com/astral-sh/python-build-standalone).
- Uses PGO+LTO optimized builds for better performance.
- Supports both x86_64 and aarch64 architectures automatically.
- No compilation required - significantly faster builds.

### Node.js Builder Stage
- Downloads pre-built Node.js binaries from nodejs.org.
- Supports both linux-x64 and linux-arm64 architectures.

### Bundle Stage
- Collects all built artifacts into a single scratch image.
- Copies Node.js, Python, Git, and jq binaries to their final locations.

### Final Image
- Based on debian:bookworm-slim.
- Copies all tools from the bundle stage.
- Creates symlinks for Python (python, python3).
- Installs runtime dependencies (curl, wget, ca-certificates, etc.).
- Installs pnpm, pm2, and node-gyp globally.

## Usage

### Tools included

| Tool     | Description                                      |
|----------|--------------------------------------------------|
| Git      | Version control system (built from source)       |
| jq       | JSON processor (built from source, static)       |
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
| Git             | 2.52.0        | Built from source             |
| jq              | 1.8.1         | Built from source (static)    |
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