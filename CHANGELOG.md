# Changelog

All notable changes to the `dgcosenza/gitea` Debian 13 container packaging and CI workflows are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Maintained by **Daniel G. Cosenza from FNX Labs**.

---
<!-- changelog:auto -->

## [28.4.0] — 2026-11-24

### Added
- Initial **Debian 13 (`trixie-slim`)** image for **Gitea 28.4.0** (official SHA-256-verified binary) with OpenSSH, Git, SQLite, static Go `environment-to-ini` helper (`GITEA__*` and `*_FILE`), and `tini` PID 1.
- Full drop-in `/data` layout compatibility (`USER_UID`/`USER_GID` user `git`, `no-new-privileges:true` via `setpriv`, `/api/healthz` healthcheck, key-only OpenSSH on port `22`).
- Seven-step automated daily CI pipeline (`.github/workflows/daily.yml`) with Trivy and Grype fixable Critical/High blocking gates, Syft SPDX SBOM, smoke test (`tests/smoke.sh`), automated docs/Hub sync, and `ci-failure` issue alerting.
