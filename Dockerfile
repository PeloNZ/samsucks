# Ubuntu amd64 toolchain: Tizen CLI, sdb, Node (dev server, remote) and esbuild.
# Build and run it with scripts/dev.sh. The Tizen tools install into the home
# volume on the first ./scripts/setup.sh.
FROM --platform=linux/amd64 ubuntu:22.04

ARG NODE_VERSION=22.12.0
ARG ESBUILD_VERSION=0.24.0
ARG BIOME_VERSION=1.9.4
ARG SHFMT_VERSION=3.10.0

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl iproute2 perl python3 shellcheck unzip zip xz-utils \
 && rm -rf /var/lib/apt/lists/*

# Checkers for scripts/check.sh: Biome (JS/CSS/JSON lint + format), shfmt (shell format).
RUN curl -fsSL "https://registry.npmjs.org/@biomejs/cli-linux-x64/-/cli-linux-x64-${BIOME_VERSION}.tgz" \
      | tar -xz -C /usr/local/bin --strip-components=1 package/biome \
 && curl -fsSL -o /usr/local/bin/shfmt "https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_amd64" \
 && chmod +x /usr/local/bin/shfmt

RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
      | tar -xJ -C /usr/local --strip-components=1 \
 && curl -fsSL "https://registry.npmjs.org/@esbuild/linux-x64/-/linux-x64-${ESBUILD_VERSION}.tgz" \
      | tar -xz -C /usr/local/bin --strip-components=2 package/bin/esbuild

# The Tizen installer refuses to run as root.
RUN useradd -m -s /bin/bash dev
USER dev
WORKDIR /work
