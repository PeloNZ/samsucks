# Ubuntu amd64 toolchain: Tizen CLI, sdb, Node (dev server, remote) and esbuild.
# Build and run it with scripts/dev.sh. The Tizen tools install into the home
# volume on the first ./scripts/setup.sh.
FROM --platform=linux/amd64 ubuntu:22.04

ARG NODE_VERSION=22.12.0
ARG ESBUILD_VERSION=0.24.0

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl iproute2 perl python3 unzip zip xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
      | tar -xJ -C /usr/local --strip-components=1 \
 && curl -fsSL "https://registry.npmjs.org/@esbuild/linux-x64/-/linux-x64-${ESBUILD_VERSION}.tgz" \
      | tar -xz -C /usr/local/bin --strip-components=2 package/bin/esbuild

# The Tizen installer refuses to run as root.
RUN useradd -m -s /bin/bash dev
USER dev
WORKDIR /work
