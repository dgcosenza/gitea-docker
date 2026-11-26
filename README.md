# Gitea — Hardened Debian 13 (trixie-slim) Image

[![Daily Gitea image](https://github.com/dgcosenza/gitea-docker/actions/workflows/daily.yml/badge.svg)](https://github.com/dgcosenza/gitea-docker/actions/workflows/daily.yml)
[![Packaging License: MIT](https://img.shields.io/badge/packaging-MIT-blue.svg)](https://github.com/dgcosenza/gitea-docker/blob/main/LICENSE)
[![Upstream License: MIT](https://img.shields.io/badge/upstream-MIT-green.svg)](https://github.com/go-gitea/gitea/blob/main/LICENSE)
[![Signed with Cosign](https://img.shields.io/badge/signed-cosign%20OIDC-blueviolet.svg)](#supply-chain-verification)
[![SLSA Level 3](https://img.shields.io/badge/SLSA-Level%203-brightgreen.svg)](#supply-chain-verification)
[![Architectures](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-informational.svg)](#supported-architectures)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/dgcosenza/gitea-docker/badge)](https://scorecard.dev/viewer/?uri=github.com/dgcosenza/gitea-docker)
[![Docker Pulls](https://img.shields.io/docker/pulls/dgcosenza/gitea)](https://hub.docker.com/r/dgcosenza/gitea)
[![Docker Image Size](https://img.shields.io/docker/image-size/dgcosenza/gitea/latest)](https://hub.docker.com/r/dgcosenza/gitea)
[![Latest Release](https://img.shields.io/github/v/release/dgcosenza/gitea-docker?label=version)](https://github.com/dgcosenza/gitea-docker/releases)

A hardened, drop-in **Gitea** container image on **Debian 13 (`trixie-slim`)** compiling the official SHA-256-verified Gitea source release with the latest stable Go toolchain and security-patched Go dependencies alongside **OpenSSH**, `git`, `sqlite3`, and `GITEA__*` environment configuration support, maintained by **Daniel G. Cosenza from FNX Labs**.

- **Docker Hub:** [`dgcosenza/gitea`](https://hub.docker.com/r/dgcosenza/gitea)
- **GitHub Container Registry (GHCR):** [`ghcr.io/dgcosenza/gitea`](https://github.com/dgcosenza/gitea-docker/pkgs/container/gitea) (identical signed multi-arch digest)
- **Source Repository:** [`dgcosenza/gitea-docker`](https://github.com/dgcosenza/gitea-docker)
- **Upstream Application:** [`go-gitea/gitea`](https://github.com/go-gitea/gitea) (MIT License)
- **Packaging License:** MIT (see [`LICENSE`](https://github.com/dgcosenza/gitea-docker/blob/main/LICENSE) and [`THIRD-PARTY-NOTICES.md`](https://github.com/dgcosenza/gitea-docker/blob/main/THIRD-PARTY-NOTICES.md))

---

## Overview

`dgcosenza/gitea` provides a drop-in replacement for the official Alpine-based `gitea/gitea` image on fully upgraded **Debian 13 (`trixie-slim`)**:

- **Drop-in `/data` & env compatibility:** Preserves `/data/gitea`, `/data/git`, `/data/ssh`, `USER_UID`/`USER_GID` (default `1000:1000`, user `git`), OpenSSH on port `22`, HTTP on port `3000`, `GITEA__SECTION__KEY` (and `*_FILE`) environment overrides via a static `environment-to-ini` binary, and `/api/healthz` healthchecks.
- **Hardened runtime:** Runs `tini` as PID 1, executes `gitea web` as non-root `git` via `setpriv` (fully compatible with `security_opt: no-new-privileges:true`), disables SSH password/root login, and ships an up-to-date Debian 13 CA certificate bundle.
- **Daily CVE-gated rebuilds (all severities with a fix):** Rebuilds daily with `--no-cache`, upgrades all Debian 13 packages (including OpenSSH, Git, OpenSSL, and CA certificates), tracks the latest official `go-gitea/gitea` release with SHA-256 verification, and enforces **0 fixable findings of any severity** in both Trivy and Grype.

---

## Current Versions

<!-- versions:start -->
| Component | Resolved Version |
| --- | --- |
| Gitea | `28.4.0` |
| Base OS | `Debian 13.8 (trixie-slim)` |
| Architectures | `linux/amd64, linux/arm64` |
| Uncompressed size (per arch) | `amd64: 128.8 MB, arm64: 363.9 MB` |
| Last verified build (UTC) | `2026-11-26` |
| Published multi-arch digest | `dgcosenza/gitea@sha256:9f8a13ba15d29e5296515cb454021d963547dfdaa91008191afba35733299f97` |
| GHCR mirror | `ghcr.io/dgcosenza/gitea@sha256:9f8a13ba15d29e5296515cb454021d963547dfdaa91008191afba35733299f97` |
| Supply chain | Cosign OIDC signed + SPDX & CycloneDX SBOM attestations + SLSA Build L3 provenance |
| Security gate (Trivy + Grype on SBOM) | **0 fixable findings of any severity** (31 upstream-unfixed) |
<!-- versions:end -->

---

## Supported Tags

| Tag | Policy | Description |
| --- | --- | --- |
| `<version>-<YYYYMMDD>` (e.g. `28.4.0-20261124`) | **Immutable** | Date-stamped daily rebuild pinning the Gitea release and UTC build date. |
| `sha-<short>` | **Immutable** | Packaging repository Git commit tag. |
| `<version>` (e.g. `28.4.0`) | Moving | Latest verified Debian 13 security rebuild of that Gitea release. |
| `latest` | Moving | Latest verified build tracking the newest official Gitea release. |

**Production pinning:** Pin by registry digest:

```yaml
image: dgcosenza/gitea:latest@sha256:<digest>
```

---

## Supported Architectures

| Architecture | Status | Verification |
| --- | --- | --- |
| `linux/amd64` | **Published & natively tested** | Built, smoke-tested, Dive-gated, Syft/Trivy/Grype-scanned, and Cosign-signed on native x86_64 CI runners. |
| `linux/arm64` | **Published & natively tested** | Built, smoke-tested, Dive-gated, Syft/Trivy/Grype-scanned, and Cosign-signed on native ARM64 CI runners. |

Identical multi-arch OCI manifest digests are published to **Docker Hub** and **GHCR** (`ghcr.io/dgcosenza/*`), accompanied by automated signed [GitHub Releases](https://github.com/dgcosenza/gitea-docker/releases).
---

## Quick Start

### `docker run`

```bash
docker run -d \
  --name gitea \
  --restart unless-stopped \
  --security-opt no-new-privileges:true \
  -p 192.0.2.10:3080:3000 \
  -p 192.0.2.10:2223:22 \
  -e USER_UID=1000 \
  -e USER_GID=1000 \
  -e TZ=Etc/UTC \
  -e GITEA__database__DB_TYPE=sqlite3 \
  -e GITEA__database__PATH=/data/gitea/gitea.db \
  -e GITEA__server__START_SSH_SERVER=false \
  -e GITEA__security__INSTALL_LOCK=true \
  -v "$(pwd)/data:/data" \
  dgcosenza/gitea:latest
```

### Docker Compose

See [`docker-compose.example.yml`](https://github.com/dgcosenza/gitea-docker/blob/main/docker-compose.example.yml).

---

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `USER` | No | `git` | Non-root user executing Gitea and receiving SSH pushes. |
| `USER_UID` / `USER_GID` | No | `1000` / `1000` | UID/GID assigned to `USER` at startup. |
| `TZ` | No | `Etc/UTC` | Container timezone (prefer `TZ` env var over bind-mounting `/etc/timezone`). |
| `GITEA_WORK_DIR` / `GITEA_CUSTOM` | No | `/data/gitea` | Gitea working and custom configuration directory. |
| `DISABLE_SSH` | No | `false` | Set `true` to disable the container's OpenSSH daemon. |
| `GITEA__<SECTION>__<KEY>` | No | *(none)* | Written automatically into `${GITEA_CUSTOM}/conf/app.ini` at boot (`__FILE` suffix reads secret value from a file). |

### Volumes, Ports, and UID/GID

| Path / Port | Mode / Owner | Purpose |
| --- | --- | --- |
| `/data/gitea` | `USER_UID:USER_GID` | `conf/app.ini`, SQLite `gitea.db`, attachments, avatars, packages, logs, sessions. |
| `/data/git` | `USER_UID:USER_GID` | Git repositories, LFS storage, `.ssh/authorized_keys`. |
| `/data/ssh` | `0:0` (`0600` keys) | Persistent OpenSSH host keys (`ed25519`, `rsa`, `ecdsa`). |
| `3000/tcp` | HTTP | Gitea web UI, Git HTTP, and OCI Container Registry. |
| `22/tcp` | SSH | OpenSSH server for Git over SSH (`GITEA__server__START_SSH_SERVER=false`). |

---

## Healthcheck

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD ["sh", "-c", "wget -q -O - http://127.0.0.1:3000/api/healthz | grep -q pass || exit 1"]
```

Probes Gitea's `/api/healthz` endpoint and requires `"status":"pass"`.

---

## Upgrading and Migrating from `gitea/gitea`

1. **Back up first:** Run `docker exec -u git gitea gitea dump -c /data/gitea/conf/app.ini` and back up `./data`.
2. Tag your outgoing image for rollback.
3. Replace `image: gitea/gitea:...` with `image: dgcosenza/gitea:latest@sha256:<digest>` keeping `./data:/data`, `USER_UID`/`USER_GID`, and `GITEA__*` variables unchanged (remove any `/etc/timezone` file bind-mount if your host OS omits `/etc/timezone` and use `TZ=...` instead).
4. Recreate the container (`docker compose up -d gitea`), verify `/api/healthz` returns `pass`, and test both Git SSH and HTTP/registry endpoints.

---

## Supply-Chain Verification

Every published digest (multi-arch index and per-architecture manifests) on both Docker Hub and GHCR is keyless-signed with **Sigstore Cosign** (GitHub OIDC), attested with **SPDX** and **CycloneDX** SBOMs, and backed by **SLSA Build L3** provenance (`actions/attest-build-provenance`).

### Verify image signature with Cosign

```bash
cosign verify \
  --certificate-identity-regexp="^https://github\.com/dgcosenza/gitea-docker/\.github/workflows/daily\.yml@refs/heads/main$" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/dgcosenza/gitea:latest

# Or against Docker Hub (identical digest):
cosign verify \
  --certificate-identity-regexp="^https://github\.com/dgcosenza/gitea-docker/\.github/workflows/daily\.yml@refs/heads/main$" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  dgcosenza/gitea:latest
```

### Verify SPDX / CycloneDX SBOM attestations and SLSA Build Provenance

```bash
cosign verify-attestation \
  --type spdxjson \
  --certificate-identity-regexp="^https://github\.com/dgcosenza/gitea-docker/\.github/workflows/daily\.yml@refs/heads/main$" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/dgcosenza/gitea@sha256:<arch-digest>

gh attestation verify oci://ghcr.io/dgcosenza/gitea:latest --owner dgcosenza
```

---

## Security

- **Vulnerability scan policy (all severities with a fix):** Every CI build verifies the upstream Gitea SHA-256, runs **Trivy** (table, JSON, SARIF upload, blocking `--ignore-unfixed` gate) and **Grype** (`--only-fixed`, severity cutoff `negligible`, blocking gate), and emits an **SPDX SBOM** (`sbom.spdx.json`) and provenance artifact.
- **Current status:** **0 fixable vulnerabilities of any severity** across Debian 13 OS packages and Gitea.
- **Hardening:** `tini` PID 1, `no-new-privileges:true` compatible via `setpriv`, OpenSSH restricted to `AllowUsers git` with key-only auth (`PasswordAuthentication no`, `PermitRootLogin no`).
- See [`SECURITY.md`](https://github.com/dgcosenza/gitea-docker/blob/main/SECURITY.md).

---

## Build Locally

```bash
git clone https://github.com/dgcosenza/gitea-docker.git
cd gitea-docker

docker buildx build \
  --platform linux/amd64 \
  --load \
  --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --build-arg IMAGE_REVISION="$(git rev-parse HEAD)" \
  -t dgcosenza/gitea:local \
  .
```

| Build Arg | Default | Purpose |
| --- | --- | --- |
| `GITEA_VERSION` | `28.4.0` | Official `go-gitea/gitea` release version (SHA-256 verified, overridden daily by CI). |
| `GO_VERSION` | `1.27.4` | Go toolchain used to compile Gitea and the static `environment-to-ini` helper. |
| `DEBIAN_BASE` | `debian:trixie-slim` | Base OS image. |

---

## Update Policy

[`.github/workflows/daily.yml`](https://github.com/dgcosenza/gitea-docker/blob/main/.github/workflows/daily.yml) runs automatically every day at **05:05 UTC**, on pushes to `main`, on pull requests (verification only), and via `workflow_dispatch`. Every scheduled run executes a seven-step automated pipeline (gated by `.github/workflows/public-check.yml`):

1. **Upstream check:** Queries `go-gitea/gitea` latest release via the authenticated GitHub API, resolves the latest stable Go toolchain and `debian:trixie-slim` digest, diffs against `versions.json`, and emits `upstream-changes.md`.
2. **No-cache rebuild:** Rebuilds `linux/amd64` and `linux/arm64` natively with `--no-cache` on schedule, verifies the official Gitea source tarball SHA-256, updates vulnerable Go modules and compiles Gitea with the latest stable Go toolchain (`bindata timetzdata`), upgrades Debian 13 packages (`apt-get update && apt-get -y upgrade`), and emits **SPDX** and **CycloneDX** SBOMs plus provenance attestations.
3. **Vulnerability fix and gate:** Runs **Trivy** (table, JSON, SARIF upload, blocking `--ignore-unfixed` gate) and **Grype** (blocking `--only-fixed` gate, severity cutoff `negligible`), diffs findings against the previous scan, and retains reports for 90 days.
4. **Smoke test:** Runs [`tests/smoke.sh`](https://github.com/dgcosenza/gitea-docker/blob/main/tests/smoke.sh) to verify Gitea version, `tini` PID 1, non-root `git` process, OpenSSH banner on port `22`, `GITEA__*` INI rendering, `/api/healthz` `pass`, and a negative closed-port check.
5. **Publish:** On non-PR builds when Docker Hub secrets are configured, pushes `latest`, `<version>`, `<version>-<YYYYMMDD>`, and `sha-<short>` tags to Docker Hub and records the immutable digest.
6. **Automated documentation sync:** Commits updated `versions.json`, the README `Current Versions` block, and a dated `CHANGELOG.md` entry via `github-actions[bot]` with `[skip ci]` when content changes, then syncs the Docker Hub overview via `peter-evans/dockerhub-description`.
7. **Failure alerting:** On failure, CI opens or updates a single GitHub issue labeled `ci-failure` with the failing job and run link, and auto-closes it on the next green run.

---

## Design Decisions

- **Debian 13 (`trixie-slim`) instead of upstream Alpine:** Upstream's official Docker image uses Alpine; migrating to Debian 13 (`trixie-slim`) standardizes glibc, OpenSSL 3, OpenSSH, and CA certificate security updates across the stack and eliminates Alpine `libxml2`/musl packaging lag.
- **Source-built from official SHA-256-verified Gitea tarball + patched Go dependencies:** Compiles the official `gitea-src-<version>.tar.gz` archive (which ships prebuilt frontend assets) with the latest stable Go toolchain and up-to-date Go security fixes (such as `github.com/klauspost/compress`, `github.com/go-chi/chi/v5`, and `golang.org/x/crypto`), preventing prebuilt-binary transitive CVEs from blocking releases while preserving full `GITEA__SECTION__KEY` and `*_FILE` drop-in compatibility via our static Go `environment-to-ini` helper.

---

## License

This repository follows a clear packaging-vs-upstream license split:

- **Container packaging, scripts, CI workflows, and documentation (`packaging: MIT`):** Licensed under the [MIT License](https://github.com/dgcosenza/gitea-docker/blob/main/LICENSE) — copyright **Daniel G. Cosenza from FNX Labs**.
- **Bundled upstream software — Gitea (`go-gitea/gitea`) (`upstream: MIT`):** Gitea is licensed under the [MIT License](https://github.com/go-gitea/gitea/blob/main/LICENSE) ([`go-gitea/gitea`](https://github.com/go-gitea/gitea)).

Full third-party notices are maintained in [`THIRD-PARTY-NOTICES.md`](https://github.com/dgcosenza/gitea-docker/blob/main/THIRD-PARTY-NOTICES.md). Release history is maintained in [`CHANGELOG.md`](https://github.com/dgcosenza/gitea-docker/blob/main/CHANGELOG.md).
