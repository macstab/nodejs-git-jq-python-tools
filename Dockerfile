# below are set three different builder images, that are building the lastest relase from source code to support
# any kind of architecture (arm, x86, x64)
# CHanger the versions by setting the version in the env variable. The versions are set to the latest version

# Set the base image for the builder stage
FROM debian:bookworm-slim as git_builder

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive
ENV GIT_VERSION=2.50.1

RUN apt-get update && \
    apt-get install -y wget make gcc autoconf libssl-dev libcurl4-openssl-dev libexpat1-dev gettext zlib1g-dev tar && \
    wget https://github.com/git/git/archive/refs/tags/v${GIT_VERSION}.tar.gz -O git.tar.gz && \
    tar -xf git.tar.gz && \
    cd git-* && \
    make prefix=/usr/local all && \
    make prefix=/usr/local install && \
    echo "Git installed"
RUN for cmd in git-add git-am git-annotate git-apply git-archive git-bisect git-blame git-branch git-bugreport git-bundle git-cat-file git-check-attr git-check-ignore git-check-mailmap git-check-ref-format git-checkout git-checkout--worker git-checkout-index git-cherry git-cherry-pick git-clean git-clone git-column git-commit git-commit-graph git-commit-tree git-config git-count-objects git-credential git-credential-cache git-credential-cache--daemon git-credential-store git-describe git-diagnose git-diff git-diff-files git-diff-index git-diff-tree git-difftool git-fast-export git-fast-import git-fetch git-fetch-pack git-fmt-merge-msg git-for-each-ref git-for-each-repo git-format-patch git-fsck git-fsck-objects git-fsmonitor--daemon git-gc git-get-tar-commit-id git-grep git-hash-object git-help git-hook git-index-pack git-init git-init-db git-interpret-trailers git-log git-ls-files git-ls-remote git-ls-tree git-mailinfo git-mailsplit git-maintenance git-merge git-merge-base git-merge-file git-merge-index git-merge-ours git-merge-recursive git-merge-subtree git-merge-tree git-mktag git-mktree git-multi-pack-index git-mv git-name-rev git-notes git-pack-objects git-pack-redundant git-pack-refs git-patch-id git-prune git-prune-packed git-pull git-push git-range-diff git-read-tree git-rebase git-receive-pack git-reflog git-remote git-remote-ext git-remote-fd git-repack git-replace git-rerere git-reset git-restore git-rev-list git-rev-parse git-revert git-rm git-send-pack git-shortlog git-show git-show-branch git-show-index git-show-ref git-sparse-checkout git-stage git-stash git-status git-stripspace git-submodule--helper git-switch git-symbolic-ref git-tag git-unpack-file git-unpack-objects git-update-index git-update-ref git-update-server-info git-upload-archive git-upload-pack git-var git-verify-commit git-verify-pack git-verify-tag git-version git-whatchanged git-worktree git-write-tree; do rm -f "/usr/local/libexec/git-core/$cmd" && ln -s /usr/local/libexec/git-core/git "/usr/local/libexec/git-core/$cmd"; done
RUN for cmd in git-remote-ftps git-remote-http git-remote-https; do rm -f "/usr/local/libexec/git-core/$cmd" && ln -s /usr/local/libexec/git-core/git-remote-ftp "/usr/local/libexec/git-core/$cmd"; done
RUN echo "Git symlinks created and optimized size"



# Create a tarball of the Git installation
RUN tar -czpf /git.tgz -C /usr/local/libexec/git-core .


# set the image for the jq builder stage
# Start by creating a build stage for jq
FROM debian:bookworm-slim as jq-builder

# Arguments for versions (if needed)
ENV JQ_VERSION=1.8.1
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies for building jq and oniguruma
RUN apt-get update && apt-get install -y \
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


# Set the base image for the Python builder stage
FROM debian:bookworm-slim as python-builder

ENV PYTHON_VERSION=3.13.0
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies and build Python from source
RUN apt-get update && \
    apt-get install -y wget build-essential libffi-dev libgdbm-dev libc6-dev \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncurses5-dev libncursesw5-dev \
    xz-utils tk-dev liblzma-dev lzma lzma-dev libgdbm-compat-dev && \
    wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && \
    tar -xf Python-${PYTHON_VERSION}.tgz && \
    cd Python-${PYTHON_VERSION} && \
    ./configure --enable-optimizations && \
    make -j `nproc` && \
    make install && \
    echo "Python installed"
#RUN    cd Python-${PYTHON_VERSION} && \
#       ./configure --enable-optimizations
#
#RUN    cd Python-${PYTHON_VERSION} && \
#       make -j `nproc`
#
#RUN    cd Python-${PYTHON_VERSION} && \
#       make install
#
#RUN    echo "Python installed"

FROM node:22.17.1-bookworm-slim AS node-builder
ENV NODE_VERSION=22.17.1
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

FROM debian:bookworm-slim AS tools
COPY --from=node-builder /usr/local /usr/local
COPY --from=git_builder /git.tgz /git.tgz
COPY --from=python-builder /usr/local/bin/python3.13 /usr/local/bin/python3.13
COPY --from=python-builder /usr/local/lib/python3.13/venv /usr/local/lib/python3.13/venv
COPY --from=python-builder /usr/local/lib/python3.13/encodings /usr/local/lib/python3.13/encodings
COPY --from=python-builder /usr/local/ /usr/local/
COPY --from=jq-builder /usr/local/bin/jq /usr/local/bin/jq
COPY --from=jq-builder /usr/local/lib/ /usr/local/lib/

FROM node:22.17.1-bookworm-slim
LABEL maintainer="Nolem / Per! <schnapka.christian@googlemail.com>"

# Set versions as build arguments
ENV PM2_VERSION=6.0.8
ENV NODE_GYP_VERSION=11.2.0
ENV PNPM_VERSION=10.13.1

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

COPY --from=tools / /

# Update symlinks for python and python3
RUN mkdir -p /usr/local/libexec/git-core && \
    tar -xzvf /git.tgz -C /usr/local/libexec/git-core && \
    ln -sfn /usr/local/bin/python3.13 /usr/local/bin/python && \
    ln -sfn /usr/local/bin/python3.13 /usr/local/bin/python3 && \
    ln -sfn /usr/local/libexec/git-core/git /usr/local/bin/git && \
    apt-get update && \
    apt-get install -y --no-install-recommends curl wget ca-certificates fontconfig binutils dumb-init bash openssl libc6 libcurl4 libgcc-s1 && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Set environment variables for pnpm's global bin directory
ENV PNPM_HOME="/usr/local/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# pnpm native package manager for arm or X86
RUN ARCH="$(dpkg --print-architecture)" && \
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
