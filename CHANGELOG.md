# Changelog

All notable changes to the `dgcosenza/gitea` Debian 13 container packaging and CI workflows are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Maintained by **Daniel G. Cosenza from FNX Labs**.

---
<!-- changelog:auto -->

## [28.4.0] — 2026-11-25

### Automated Daily Build
- Verified components: Gitea `28.4.0`, Base OS `Debian 13.8 (trixie-slim)`.
- Architectures verified: `linux/amd64, linux/arm64` (native smoke tests + Dive efficiency gate).
- Upstream status: no new upstream release since previous build; refreshed base OS and dependencies.
- Vulnerability gate: **0 fixable Critical/High** in Trivy and Grype (SBOM scan) (31 upstream-unfixed).
- Published multi-arch digest (Docker Hub + GHCR): `dgcosenza/gitea@sha256:bdcf0b12034181fbf9175e879b452680b8919a6471be5f6d5e8664d34333374d` (Cosign OIDC signed + SPDX/CycloneDX SBOM + SLSA L3 provenance).
---

## [28.4.0] — 2026-11-24

### Added
- Initial **Debian 13 (`trixie-slim`)** image for **Gitea 28.4.0** (official SHA-256-verified binary) with OpenSSH, Git, SQLite, static Go `environment-to-ini` helper (`GITEA__*` and `*_FILE`), and `tini` PID 1.
- Full drop-in `/data` layout compatibility (`USER_UID`/`USER_GID` user `git`, `no-new-privileges:true` via `setpriv`, `/api/healthz` healthcheck, key-only OpenSSH on port `22`).
- Seven-step automated daily CI pipeline (`.github/workflows/daily.yml`) with Trivy and Grype fixable Critical/High blocking gates, Syft SPDX SBOM, smoke test (`tests/smoke.sh`), automated docs/Hub sync, and `ci-failure` issue alerting.
