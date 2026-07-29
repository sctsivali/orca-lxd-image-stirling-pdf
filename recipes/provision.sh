#!/usr/bin/env bash
set -euo pipefail

version=2.14.2
asset=Stirling-PDF-server.jar
url="https://github.com/Stirling-Tools/Stirling-PDF/releases/download/v${version}/${asset}"
sha256=20159880475e8fc00483423405b44c48058557e3ff197baa87ebacf5d22d37c2
java_asset=OpenJDK25U-jre_x64_linux_hotspot_25.0.4_7.tar.gz
java_url="https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4%2B7/${java_asset}"
java_sha256=aed3915f8facc0c80733ab2448bb0df4b494a36a2c5759e9a6e1eb979720f2b3

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl tar tini
rm -rf /var/lib/apt/lists/*

curl --fail --location --retry 5 --output "/tmp/${java_asset}" "$java_url"
printf '%s  %s\n' "$java_sha256" "/tmp/${java_asset}" | sha256sum --check
install -d -o root -g root -m 0755 /opt/java
tar --extract --gzip --file "/tmp/${java_asset}" --directory /opt/java --strip-components=1
rm -f "/tmp/${java_asset}"

if ! getent group stirling-pdf >/dev/null; then groupadd --system --gid 988 stirling-pdf; fi
if ! id stirling-pdf >/dev/null 2>&1; then
  useradd --system --uid 988 --gid stirling-pdf --home-dir /var/lib/stirling-pdf --shell /usr/sbin/nologin stirling-pdf
fi
install -d -o root -g root -m 0755 /opt/stirling-pdf /usr/local/libexec
install -d -o stirling-pdf -g stirling-pdf -m 0750 /var/lib/stirling-pdf
curl --fail --location --retry 5 --output "/opt/stirling-pdf/${asset}" "$url"
printf '%s  %s\n' "$sha256" "/opt/stirling-pdf/${asset}" | sha256sum --check
chmod 0644 "/opt/stirling-pdf/${asset}"
printf '%s\n' "$version" >/opt/stirling-pdf/VERSION

cat >/usr/local/libexec/stirling-volume-init <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
install -d -o stirling-pdf -g stirling-pdf -m 0750 \
  /var/lib/stirling-pdf \
  /var/lib/stirling-pdf/configs \
  /var/lib/stirling-pdf/logs \
  /var/lib/stirling-pdf/customFiles \
  /var/lib/stirling-pdf/pipeline \
  /var/lib/stirling-pdf/pipeline/watchedFolders \
  /var/lib/stirling-pdf/pipeline/finishedFolders \
  /var/lib/stirling-pdf/storage \
  /var/lib/stirling-pdf/tmp
EOF
chmod 0755 /usr/local/libexec/stirling-volume-init

for path in configs logs customFiles pipeline storage; do
  ln -sfn "/var/lib/stirling-pdf/$path" "/opt/stirling-pdf/$path"
done

cat >/etc/systemd/system/stirling-pdf.service <<EOF
[Unit]
Description=Stirling PDF
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=stirling-pdf
Group=stirling-pdf
WorkingDirectory=/opt/stirling-pdf
ExecStartPre=+/usr/local/libexec/stirling-volume-init
ExecStart=/usr/bin/tini -s -- /opt/java/bin/java -XX:+ExitOnOutOfMemoryError -XX:MaxRAMPercentage=70 -Djava.awt.headless=true -jar /opt/stirling-pdf/${asset}
Restart=on-failure
RestartSec=5
Environment=SERVER_PORT=8080
Environment=SECURITY_ENABLELOGIN=false
Environment=SYSTEM_DEFAULTLOCALE=en-US
Environment=STIRLING_TEMPFILES_DIRECTORY=/var/lib/stirling-pdf/tmp
Environment=TMPDIR=/var/lib/stirling-pdf/tmp
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=/var/lib/stirling-pdf
CapabilityBoundingSet=
AmbientCapabilities=
LockPersonality=true
RestrictSUIDSGID=true

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now stirling-pdf.service
