# Multi-arch Docker image with Node.js, Git, jq, yq, and Python
# Supports both arm64 and x86_64 architectures
# Change versions by setting the ENV variables in each builder stage

########################
# 1) BUILD STAGES
########################

# ----------------------------------------------------------
# Download pre-built jq and yq binaries
FROM debian:bookworm-slim AS tools-builder

ENV JQ_VERSION=1.8.1
ENV YQ_VERSION=4.50.1
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    ARCH="$(dpkg --print-architecture)" && \
    if [ "$ARCH" = "amd64" ]; then \
        JQ_ARCH="linux-amd64"; \
        YQ_ARCH="linux_amd64"; \
    elif [ "$ARCH" = "arm64" ]; then \
        JQ_ARCH="linux-arm64"; \
        YQ_ARCH="linux_arm64"; \
    else \
        echo "Unsupported architecture $ARCH" && exit 1; \
    fi && \
    wget -O /usr/local/bin/jq "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-${JQ_ARCH}" && \
    wget -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_${YQ_ARCH}" && \
    chmod +x /usr/local/bin/jq /usr/local/bin/yq


# ----------------------------------------------------------
# Download pre-built Python from python-build-standalone (PGO+LTO optimized)
FROM debian:bookworm-slim AS python-builder

ENV PYTHON_VERSION=3.13.11
ENV PYTHON_BUILD_DATE=20251205
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    ARCH="$(dpkg --print-architecture)" && \
    if [ "$ARCH" = "amd64" ]; then \
        PY_ARCH="x86_64"; \
    elif [ "$ARCH" = "arm64" ]; then \
        PY_ARCH="aarch64"; \
    else \
        echo "Unsupported architecture $ARCH" && exit 1; \
    fi && \
    wget -O python.tar.gz "https://github.com/astral-sh/python-build-standalone/releases/download/${PYTHON_BUILD_DATE}/cpython-${PYTHON_VERSION}+${PYTHON_BUILD_DATE}-${PY_ARCH}-unknown-linux-gnu-install_only_stripped.tar.gz" && \
    mkdir -p /opt && \
    tar -xzf python.tar.gz -C /opt && \
    rm python.tar.gz

# ----------------------------------------------------------
FROM node:24.13.0-bookworm-slim AS node-builder
ENV NODE_VERSION=24.13.0
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y wget xz-utils ca-certificates && rm -rf /var/lib/apt/lists/*

RUN ARCH="$(dpkg --print-architecture)" && \
    if [ "$ARCH" = "amd64" ]; then \
        NODE_ARCH="linux-x64"; \
    elif [ "$ARCH" = "arm64" ]; then \
        NODE_ARCH="linux-arm64"; \
    else \
        echo "Unsupported architecture $ARCH" && exit 1; \
    fi && \
    wget -O node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-${NODE_ARCH}.tar.xz" && \
    tar -xJf node.tar.xz -C /usr/local --strip-components=1 && \
    rm node.tar.xz

###############################################
# 2) BUNDLE STAGE (one place to collect files)
###############################################

# ----------------------------------------------------------
FROM scratch AS bundle
# Node
COPY --from=node-builder   /usr/local                           /usr/local
COPY --from=node-builder   /opt                                 /opt
# Python (from python-build-standalone)
COPY --from=python-builder /opt/python/bin/                     /usr/local/bin/
COPY --from=python-builder /opt/python/lib/python3.13           /usr/local/lib/python3.13
# jq and yq (pre-built binaries)
COPY --from=tools-builder  /usr/local/bin/jq                    /usr/local/bin/jq
COPY --from=tools-builder  /usr/local/bin/yq                    /usr/local/bin/yq


# ----------------------------------------------------------
FROM debian:bookworm-slim
LABEL maintainer="Nolem / Per! <schnapka.christian@googlemail.com>"

# Set versions as build arguments
ENV PM2_VERSION=6.0.14
ENV NODE_GYP_VERSION=12.1.0
ENV PNPM_VERSION=10.28.0

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Set environment variables for pnpm's global bin directory
ENV PNPM_HOME="/usr/local/pnpm"
ENV PATH="$PNPM_HOME:$PATH"


COPY --from=bundle / /

# Update symlinks for python and python3
RUN ln -sfn /usr/local/bin/python3.13 /usr/local/bin/python && \
    ln -sfn /usr/local/bin/python3.13 /usr/local/bin/python3 && \
    echo "deb http://deb.debian.org/debian sid main" >> /etc/apt/sources.list.d/sid.list && \
    echo 'APT::Default-Release "bookworm";' > /etc/apt/apt.conf.d/99defaultrelease && \
    apt-get update && \
    apt-get install -y --no-install-recommends curl wget ca-certificates fontconfig binutils dumb-init bash openssl libc6 libcurl4 libgcc-s1 && \
    apt-get install -y -t sid git && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean && \
    ARCH="$(dpkg --print-architecture)" && \
    if [ "$ARCH" = "amd64" ]; then \
        BIN_ARCH="x64"; \
    elif [ "$ARCH" = "arm64" ]; then \
        BIN_ARCH="arm64"; \
    else \
        echo "Unsupported architecture $ARCH" && exit 1; \
    fi && \
    wget -O /usr/local/bin/pnpm "https://github.com/pnpm/pnpm/releases/download/v${PNPM_VERSION}/pnpm-linuxstatic-$BIN_ARCH" && \
    chmod +x /usr/local/bin/pnpm && \
    pnpm install -g pm2@${PM2_VERSION} && \
    pnpm install -g node-gyp@${NODE_GYP_VERSION} && \
    echo "Node.js version: $(node --version)" && \
    echo "npm version: $(npm --version)" && \
    echo "Yarn version: $(yarn --version)" && \
    echo "Python version: $(python3 --version)" && \
    echo "pnpm version: $(pnpm --version)" && \
    echo "Git version: $(git --version)" && \
    echo "jq version: $(jq --version)" && \
    echo "yq version: $(yq --version)"
