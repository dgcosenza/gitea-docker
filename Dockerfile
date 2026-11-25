# syntax=docker/dockerfile:1.7

ARG GO_VERSION=1.27.4
ARG DEBIAN_BASE=debian:trixie-slim
ARG GITEA_VERSION=28.4.0

# ---- Stage 1: build static environment-to-ini helper & fetch SHA-256 verified Gitea binary ----
FROM golang:${GO_VERSION}-trixie AS builder

ARG GITEA_VERSION
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src/env2ini
COPY tools/environment-to-ini/ ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GOTOOLCHAIN=local \
    go build -trimpath -ldflags="-s -w" -o /out/environment-to-ini ./main.go

# Download official upstream Gitea Linux amd64 release binary and verify SHA-256 checksum
RUN set -eux; \
    BASE="https://github.com/go-gitea/gitea/releases/download/v${GITEA_VERSION}"; \
    curl -fsSLo /out/gitea "${BASE}/gitea-${GITEA_VERSION}-linux-amd64"; \
    curl -fsSLo /tmp/gitea.sha256 "${BASE}/gitea-${GITEA_VERSION}-linux-amd64.sha256"; \
    EXPECTED="$(awk '{print $1}' /tmp/gitea.sha256)"; \
    echo "${EXPECTED}  /out/gitea" | sha256sum -c -; \
    chmod 0755 /out/gitea /out/environment-to-ini; \
    rm -f /tmp/gitea.sha256

# ---- Stage 2: hardened Debian 13 (trixie-slim) Gitea + OpenSSH runtime ----
FROM ${DEBIAN_BASE} AS runtime

ARG GITEA_VERSION
ARG GO_VERSION
ARG BUILD_DATE=unknown
ARG IMAGE_REVISION=""
ARG IMAGE_SOURCE="https://github.com/dgcosenza/gitea-docker"
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y --no-install-recommends \
       bash ca-certificates curl gettext-base git gnupg openssh-server \
       passwd procps sqlite3 tini tzdata util-linux wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create default git user/group (UID/GID 1000, unlocked for SSH pubkey auth, reconciled at boot)
RUN groupadd --gid 1000 git \
    && useradd --uid 1000 --gid 1000 --no-create-home --home-dir /data/git \
       --shell /bin/bash --comment 'Gitea service account' git \
    && usermod -p '*' git \
    && mkdir -p /app/gitea /data /etc/templates /run/sshd

COPY --from=builder --chown=0:0 /out/gitea /usr/local/bin/gitea
COPY --from=builder --chown=0:0 /out/environment-to-ini /usr/local/bin/environment-to-ini
COPY templates/ /etc/templates/
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/gitea /usr/local/bin/environment-to-ini /usr/local/bin/docker-entrypoint.sh

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
      org.opencontainers.image.description="Hardened Debian 13 (trixie-slim) Gitea container with OpenSSH and GITEA__* INI configuration support, maintained by Daniel G. Cosenza from FNX Labs." \
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
