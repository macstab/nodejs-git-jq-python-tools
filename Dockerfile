# Multi-arch Docker image with Node.js, Git, jq, and Python
# Supports both arm64 and x86_64 architectures
# Change versions by setting the ENV variables in each builder stage

########################
# 1) BUILD STAGES
########################

# Set the base image for the builder stage
FROM debian:bookworm-slim AS git-builder

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive
ENV GIT_VERSION=2.52.0

RUN apt-get update && \
    apt-get install -y wget make gcc autoconf libssl-dev libcurl4-openssl-dev libexpat1-dev gettext zlib1g-dev tar && \
    wget https://github.com/git/git/archive/refs/tags/v${GIT_VERSION}.tar.gz -O git.tar.gz && \
    tar -xf git.tar.gz && \
    cd git-* && \
    make -j"$(nproc)" \
        prefix=/usr/local \
        gitexecdir=/usr/local/libexec/git-core \
        NO_TCLTK=YesPlease NO_GETTEXT=YesPlease NO_PYTHON=YesPlease NO_PERL=YesPlease \
        all; \
    make prefix=/usr/local \
         NO_INSTALL_HARDLINKS=YesPlease \
         install && \
    echo "Git installed in /opt/git-core"


# ----------------------------------------------------------
# set the image for the jq builder stage
# Start by creating a build stage for jq
FROM debian:bookworm-slim AS jq-builder

# Arguments for versions (if needed)
ENV JQ_VERSION=1.8.1
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies for building jq and oniguruma
RUN apt-get update  \
    && apt-get install --no-install-recommends -y \
    autoconf \
    automake \
    build-essential \
    libtool \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Clone jq from the official repository
RUN git clone https://github.com/jqlang/jq.git && \
    cd jq && \
    git checkout jq-${JQ_VERSION} && \
    git submodule update --init && \
    autoreconf -i && \
    ./configure --with-oniguruma=builtin --prefix=/usr/local && \
    make LDFLAGS=-all-static && \
    make -j8 && \
    make check && \
    make install


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
# Git
COPY --from=git-builder    /usr/local/libexec/git-core          /usr/local/libexec/git-core
COPY --from=git-builder    /usr/local/bin/git                   /usr/local/bin/git
# jq (static)
COPY --from=jq-builder     /usr/local/bin/jq                    /usr/local/bin/jq
COPY --from=jq-builder     /usr/local/lib/                      /usr/local/lib/


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
    ln -sfn /usr/local/libexec/git-core/git /usr/local/bin/git && \
    apt-get update && \
    apt-get install -y --no-install-recommends curl wget ca-certificates fontconfig binutils dumb-init bash openssl libc6 libcurl4 libgcc-s1 && \
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
    echo "jq version: $(jq --version)"
