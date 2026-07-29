# ORCA LXD Image — Stirling PDF

Reproducible Ubuntu 24.04 LXD container image for **Stirling PDF 2.14.2**.

## Install and build

Requirements: LXD access to the designated isolated build project, `vpc-core0`, and `right-wing-pool`.

```bash
PROJECT=ORCA-build-d \
INSTANCE=stirling-pdf-build-d \
VOLUME=stirling-pdf-data-d \
STORAGE=right-wing-pool \
NETWORK=vpc-core0 \
ROOT_SIZE=10GiB \
./recipes/build.sh
```

The recipe downloads the official release JAR and verifies its pinned SHA-256 before installation. The data volume is attached before the application is installed or started.

## Access

The application listens on HTTP port `8080` on a private instance address. Public access is only through OrcaHub Exposer with automatic TLS. Login is disabled by default, so operators must not directly expose the private address.

## Persistence

Persistent state is stored under `/var/lib/stirling-pdf` on the required `stirling-data` volume. It includes configuration, logs, custom files, pipeline folders, storage, and runtime temp data. The service initializes ownership narrowly as UID/GID `992:992` during every start, including an empty first-boot volume.

## Backup and upgrade

1. Stop `stirling-pdf.service` or the instance.
2. Snapshot or back up the `stirling-data` custom volume.
3. Build a new exact-version image; never replace an immutable artifact.
4. Attach a clone of the volume to an isolated acceptance instance.
5. Run the full readiness, restart, and persistence suite before moving a mutable alias.

## Security

The service runs as an unprivileged system user with no login shell. The systemd unit uses a read-only system view, empty capability sets, `NoNewPrivileges`, private temporary storage, and a single declared writable data path. No passwords, SSH host keys, machine identity, API tokens, or private keys belong in the published image.

## Troubleshooting

```bash
systemctl status stirling-pdf
journalctl -u stirling-pdf --no-pager -n 200
curl -fsS http://127.0.0.1:8080/api/v1/info/status
```

Keep sanitized failure logs before removing a failed qualification instance.

## Rollback

Stop the failed version, reattach the last verified volume snapshot to the prior immutable image, launch it privately, and rerun readiness and persistence checks before restoring Exposer routing.

## Provenance

- Upstream source: https://github.com/Stirling-Tools/Stirling-PDF
- Upstream homepage: https://www.stirlingpdf.com/
- Release: https://github.com/Stirling-Tools/Stirling-PDF/releases/tag/v2.14.2
- Logo source: https://github.com/Stirling-Tools/Stirling-PDF/blob/v2.14.2/frontend/shared/assets/brand/classic-logo/logo512.png
