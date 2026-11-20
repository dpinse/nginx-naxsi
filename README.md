# nginx-naxsi

Mainline **NGINX** compiled with **NAXSI** (`wargio/naxsi`) as a dynamic module (`ngx_http_naxsi_module.so`) on **Alpine Linux**, designed for runtime-mounted configuration and rule sets with automated version bumps and multi-architecture container builds.

## Architecture & Layout

- **Dynamic Module:** NGINX mainline is built with NAXSI compiled as a dynamic module so you can enable or tune WAF rules at runtime via `/etc/nginx/nginx.conf`.
- **Runtime Mounts:** Configuration (`nginx.conf`) and NAXSI rule sets (`naxsi/`) are mounted into the container at runtime rather than baked into the image.
- **Synced Rules + Custom Overrides:** `scripts/sync-naxsi-rules.sh` pulls `naxsi_core.rules`, `blocking/`, and `whitelists/` from upstream `wargio/naxsi` releases for `NAXSI_VERSION` while preserving custom rule files (such as `app.rules`).

```text
.
├── .github/
│   └── workflows/
│       ├── build.yml            # Smoke test, multi-arch build, OCI metadata, Cosign
│       └── bump-versions.yml    # Automated NGINX & NAXSI release checks + PRs
├── conf/
│   └── nginx.conf               # Example/mounted NGINX configuration
├── naxsi/
│   ├── naxsi_core.rules         # Core NAXSI definitions (http context)
│   ├── blocking/                # Upstream blocking rule files (http context)
│   ├── whitelists/              # Upstream whitelist rule files
│   └── app.rules                # CheckRule thresholds & overrides (location context)
├── scripts/
│   └── sync-naxsi-rules.sh      # Syncs upstream naxsi_rules for a target NAXSI version
├── versions.env                 # Source of truth for NGINX_VERSION and NAXSI_VERSION
└── Dockerfile
```
## Quick Start (Docker Compose)

Run this from the repository root to sync the NAXSI rules for `NAXSI_VERSION`, ensure `conf/nginx.conf` is a regular file, and start the existing Docker Compose stack:

```bash
set -euo pipefail

source versions.env
./scripts/sync-naxsi-rules.sh "${NAXSI_VERSION}" naxsi

mkdir -p conf
[ -d conf/nginx.conf ] && rm -rf conf/nginx.conf
[ -f conf/nginx.conf ] || cp nginx.conf conf/nginx.conf

docker compose up -d