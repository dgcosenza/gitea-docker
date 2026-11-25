# Security Policy

Maintained by **Daniel G. Cosenza from FNX Labs**.

## Supported Versions

Only the latest daily build of `dgcosenza/gitea` packaging the official SHA-256-verified Gitea release on Debian 13 (`trixie-slim`) is actively maintained and receives automated security rebuilds.

## Automated Vulnerability Scanning

Every build in GitHub Actions enforces:
- Official SHA-256 verification of `gitea-<version>-linux-amd64` against upstream `go-gitea/gitea` release checksums.
- **Trivy** (`--ignore-unfixed`, severity `CRITICAL,HIGH`) blocking gate + table/JSON reports + SARIF upload to GitHub Code Scanning.
- **Grype** (`--only-fixed`, severity cutoff `high`) blocking gate + persisted report artifact.
- **Syft** SPDX SBOM (`sbom.spdx.json`) and build provenance artifacts.

## Reporting a Vulnerability

- **Container packaging or CI issues:** Open a private security advisory via GitHub Security Advisories on [`dgcosenza/gitea-docker`](https://github.com/dgcosenza/gitea-docker/security/advisories/new).
- **Upstream Gitea issues:** Report via Gitea's security policy at [`go-gitea/gitea`](https://github.com/go-gitea/gitea/security/policy).
