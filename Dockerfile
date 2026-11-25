# syntax=docker/dockerfile:1.7

ARG GO_BASE=golang:1.27.4-trixie@sha256:430985542100b871e108ccc00e8dcc5eef08ca14ee5825e98ebf563d8ffec4ee
ARG DEBIAN_BASE=debian:trixie-slim@sha256:8aa5a7bf5a1955bddbe7d74fcdd0b91ab30e74362a8b73af672b0481b35b44a0
ARG GO_VERSION=1.27.4
ARG GITEA_VERSION=28.4.0

# ---- Stage 1: build static environment-to-ini helper & compile Gitea from SHA-256-verified source ----
FROM ${GO_BASE} AS builder
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG GITEA_VERSION
ARG TARGETARCH
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src/env2ini
COPY tools/environment-to-ini/ ./

# Build static environment-to-ini helper
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    set -eux; \
    ARCH="${TARGETARCH:-amd64}"; \
    CGO_ENABLED=0 GOOS=linux GOARCH="${ARCH}" GOTOOLCHAIN=local \
      go build -trimpath -ldflags="-s -w" -o /out/environment-to-ini ./main.go; \
    chmod 0755 /out/environment-to-ini

WORKDIR /src/gitea

# Fetch official SHA-256-verified Gitea source archive (with prebuilt frontend assets),
# patch vulnerable transitive Go modules, and compile static pure-Go Gitea binary
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    set -eux; \
    ARCH="${TARGETARCH:-amd64}"; \
    BASE="https://github.com/go-gitea/gitea/releases/download/v${GITEA_VERSION}"; \
    curl -fsSLo /tmp/gitea-src.tar.gz "${BASE}/gitea-src-${GITEA_VERSION}.tar.gz"; \
    curl -fsSLo /tmp/gitea-src.tar.gz.sha256 "${BASE}/gitea-src-${GITEA_VERSION}.tar.gz.sha256"; \
    EXPECTED="$(awk '{print $1}' /tmp/gitea-src.tar.gz.sha256)"; \
    echo "${EXPECTED}  /tmp/gitea-src.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/gitea-src.tar.gz -C /src/gitea --strip-components=1; \
    rm -rf /tmp/gitea-src.tar.gz /tmp/gitea-src.tar.gz.sha256 /src/gitea/vendor; \
    GOTOOLCHAIN=local go get \
      github.com/klauspost/compress@latest \
      github.com/go-chi/chi/v5@latest \
      golang.org/x/crypto@latest; \
    TAGS="bindata timetzdata"; \
    CGO_ENABLED=0 GOTOOLCHAIN=local go generate -tags "${TAGS}" ./...; \
    CGO_ENABLED=0 GOOS=linux GOARCH="${ARCH}" GOTOOLCHAIN=local \
      go build -trimpath -tags "${TAGS}" \
      -ldflags="-s -w -X 'main.Version=${GITEA_VERSION}' -X 'main.Tags=${TAGS}'" \
      -o /out/gitea .; \
    chmod 0755 /out/gitea; \
    rm -rf /src/gitea/* /src/gitea/.[!.]*

# ---- Stage 2: hardened Debian 13 (trixie-slim) Gitea + OpenSSH runtime ----
FROM ${DEBIAN_BASE} AS runtime

ARG GITEA_VERSION
ARG GO_VERSION
ARG BUILD_DATE=unknown
ARG IMAGE_REVISION=""
ARG IMAGE_SOURCE="https://github.com/dgcosenza/gitea-docker"
ARG DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y --no-install-recommends \
      bash ca-certificates curl gettext-base git gnupg openssh-server \
      passwd procps sqlite3 tini tzdata util-linux wget; \
    rm -f /etc/ssh/ssh_host_*; \
    groupadd --gid 1000 git; \
    useradd --uid 1000 --gid 1000 --no-create-home --home-dir /data/git \
      --shell /bin/bash --comment 'Gitea service account' git; \
    usermod -p '*' git; \
    mkdir -p /app/gitea /data /etc/templates /run/sshd; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=builder --chown=0:0 --chmod=0755 /out/gitea /usr/local/bin/gitea
COPY --from=builder --chown=0:0 --chmod=0755 /out/environment-to-ini /usr/local/bin/environment-to-ini
COPY templates/ /etc/templates/
COPY --chmod=0755 scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENV USER=git \
    USER_UID=1000 \
    USER_GID=1000 \
    GITEA_WORK_DIR=/data/gitea \
    GITEA_CUSTOM=/data/gitea \
    TZ=Etc/UTC

EXPOSE 22 3000
VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD ["sh", "-c", "wget -q -O - http://127.0.0.1:3000/api/healthz | grep -q pass || exit 1"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]

LABEL org.opencontainers.image.title="Gitea (Debian 13)" \
      org.opencontainers.image.description="Hardened multi-arch Debian 13 (trixie-slim) Gitea container with OpenSSH and GITEA__* INI configuration support, maintained by Daniel G. Cosenza from FNX Labs." \
      org.opencontainers.image.url="https://hub.docker.com/r/dgcosenza/gitea" \
      org.opencontainers.image.source="${IMAGE_SOURCE}" \
      org.opencontainers.image.documentation="${IMAGE_SOURCE}#readme" \
      org.opencontainers.image.version="${GITEA_VERSION}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Daniel G. Cosenza from FNX Labs" \
      org.opencontainers.image.authors="Daniel G. Cosenza from FNX Labs" \
      org.opencontainers.image.base.name="debian:trixie-slim" \
      io.github.dgcosenza.gitea.upstream_repo="https://github.com/go-gitea/gitea" \
      io.github.dgcosenza.gitea.upstream_version="${GITEA_VERSION}"
