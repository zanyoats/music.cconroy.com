#!/bin/sh
set -eu

exec > /var/log/user-data.log 2>&1
echo "user-data start: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

finish() {
  status="$?"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [ "${status}" -eq 0 ]; then
    echo "user-data ok: ${timestamp}" | tee /var/log/user-data.ok
  else
    echo "user-data failed (${status}): ${timestamp}" | tee /var/log/user-data.failed
  fi

  exit "${status}"
}
trap finish EXIT

start_service() {
  service_name="$1"

  if rc-service "${service_name}" status >/dev/null 2>&1; then
    echo "service ${service_name} already started"
  else
    rc-service "${service_name}" start
  fi
}

enable_service() {
  service_name="$1"
  runlevel="$2"

  if [ -e "/etc/runlevels/${runlevel}/${service_name}" ]; then
    echo "service ${service_name} already enabled in runlevel ${runlevel}"
  else
    rc-update add "${service_name}" "${runlevel}"
  fi
}

APP_PORT="4533"
DOMAIN="music.cconroy.com"
CADDY_LOG_DIR="/var/log/caddy"
KUKICHA_LOG_DIR="/var/log/kukicha"
UV_INSTALL_DIR="/usr/local/bin"
UV_TOOL_DIR="/opt/uv/tools"
UV_TOOL_BIN_DIR="/usr/local/bin"

export HOME="/root"
export XDG_CONFIG_HOME="/root/.config"
mkdir -p "${XDG_CONFIG_HOME}"
chmod 700 "${XDG_CONFIG_HOME}"

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

mkdir -p "${CADDY_LOG_DIR}"
touch "${CADDY_LOG_DIR}/caddy.log" "${CADDY_LOG_DIR}/access.log"
if id -u caddy >/dev/null 2>&1; then
  chown caddy:caddy "${CADDY_LOG_DIR}" "${CADDY_LOG_DIR}/caddy.log" "${CADDY_LOG_DIR}/access.log"
fi
chmod 755 "${CADDY_LOG_DIR}"
chmod 644 "${CADDY_LOG_DIR}/caddy.log" "${CADDY_LOG_DIR}/access.log"

cat > /etc/caddy/Caddyfile <<EOF
{
	log {
		output file ${CADDY_LOG_DIR}/caddy.log {
			roll_size 10MiB
			roll_keep 5
			roll_keep_for 720h
		}
	}
}

${DOMAIN} {
	log {
		output file ${CADDY_LOG_DIR}/access.log {
			roll_size 10MiB
			roll_keep 5
			roll_keep_for 720h
		}
	}

	reverse_proxy 127.0.0.1:${APP_PORT}
}
EOF
caddy fmt --overwrite /etc/caddy/Caddyfile

mkdir -p "${UV_TOOL_DIR}" "${UV_TOOL_BIN_DIR}"
if [ -x "${UV_INSTALL_DIR}/uv" ]; then
  echo "uv already installed at ${UV_INSTALL_DIR}/uv"
else
  uv_installer="$(mktemp)"
  curl -LsSf https://astral.sh/uv/install.sh -o "${uv_installer}"
  env UV_UNMANAGED_INSTALL="${UV_INSTALL_DIR}" sh "${uv_installer}"
  rm -f "${uv_installer}"
fi

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

start_service sshd
enable_service sshd default

enable_service kukicha default

enable_service caddy default

ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https

if ufw status | grep -q "Status: active"; then
  echo "ufw already active"
else
  ufw --force enable
fi
start_service ufw
enable_service ufw default
