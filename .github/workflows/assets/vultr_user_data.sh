#!/bin/sh
set -eu

exec > /var/log/user-data.log 2>&1
echo "user-data start: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

APP_PORT="4533"
DOMAIN="music.cconroy.com"
KUKICHA_LOG_DIR="/var/log/kukicha"
UV_INSTALL_DIR="/usr/local/bin"
UV_TOOL_DIR="/opt/uv/tools"
UV_TOOL_BIN_DIR="/usr/local/bin"

ALPINE_VERSION="$(cut -d. -f1,2 /etc/alpine-release)"
COMMUNITY_REPO="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community"
if ! grep -qs "${COMMUNITY_REPO}" /etc/apk/repositories; then
  echo "${COMMUNITY_REPO}" >> /etc/apk/repositories
fi

apk add --no-cache \
  ufw \
  openssh \
  rsync \
  curl \
  ca-certificates \
  caddy \
  acl \
  tzdata

cat > /etc/caddy/Caddyfile <<EOF
${DOMAIN} {
	reverse_proxy 127.0.0.1:${APP_PORT}
}
EOF
caddy fmt --overwrite /etc/caddy/Caddyfile

mkdir -p "${UV_TOOL_DIR}" "${UV_TOOL_BIN_DIR}"
curl -LsSf https://astral.sh/uv/install.sh | env UV_UNMANAGED_INSTALL="${UV_INSTALL_DIR}" sh

mkdir -p "${KUKICHA_LOG_DIR}"
chmod 755 "${KUKICHA_LOG_DIR}"
cat > /etc/init.d/kukicha <<'EOF'
#!/sbin/openrc-run

name="kukicha"
description="Kukicha music HTTP server"

supervisor="supervise-daemon"
command="/usr/local/bin/kukicha"
directory="/root"
pidfile="/run/kukicha.pid"
output_log="/var/log/kukicha/kukicha.log"
error_log="/var/log/kukicha/kukicha.err.log"
respawn_delay=5
respawn_max=0

export HOME="/root"
export XDG_CONFIG_HOME="/root/.config"

depend() {
	need net
}
EOF
chmod 755 /etc/init.d/kukicha

rc-service sshd start
rc-update add sshd default

rc-update add kukicha default

rc-update add caddy default

ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw --force enable
rc-service ufw start
rc-update add ufw default

echo "user-data ok: $(date -u +%Y-%m-%dT%H:%M:%SZ)" > /var/log/user-data.ok
