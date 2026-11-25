#!/usr/bin/env bash
set -euo pipefail

export USER="${USER:-git}"
export USER_UID="${USER_UID:-1000}"
export USER_GID="${USER_GID:-1000}"
export GITEA_WORK_DIR="${GITEA_WORK_DIR:-/data/gitea}"
export GITEA_CUSTOM="${GITEA_CUSTOM:-/data/gitea}"

# Reconcile git user/group to USER_UID/USER_GID when running as root
if [ "$(id -u)" -eq 0 ]; then
  if [ "$USER" != "git" ] && ! id "$USER" >/dev/null 2>&1; then
    usermod -l "$USER" git
  fi
  if [ "$(id -g "$USER")" != "$USER_GID" ]; then
    groupmod -o -g "$USER_GID" git
  fi
  if [ "$(id -u "$USER")" != "$USER_UID" ]; then
    usermod -o -u "$USER_UID" "$USER"
  fi
fi

mkdir -p /data/gitea/conf /data/gitea/log /data/git/.ssh /data/ssh /run/sshd
chmod 700 /data/git/.ssh /data/ssh
[ -f /data/git/.ssh/authorized_keys ] && chmod 600 /data/git/.ssh/authorized_keys

printf 'GITEA_CUSTOM=%s\n' "$GITEA_CUSTOM" > /data/git/.ssh/environment
chmod 600 /data/git/.ssh/environment

# Generate persistent SSH host keys if missing
if [ ! -f /data/ssh/ssh_host_ed25519_key ]; then
  ssh-keygen -t ed25519 -f /data/ssh/ssh_host_ed25519_key -N "" >/dev/null
fi
if [ ! -f /data/ssh/ssh_host_rsa_key ]; then
  ssh-keygen -t rsa -b 3072 -f /data/ssh/ssh_host_rsa_key -N "" >/dev/null
fi
if [ ! -f /data/ssh/ssh_host_ecdsa_key ]; then
  ssh-keygen -t ecdsa -b 256 -f /data/ssh/ssh_host_ecdsa_key -N "" >/dev/null
fi
chmod 600 /data/ssh/ssh_host_*_key

# Render sshd_config
SSH_LISTEN_PORT="${SSH_LISTEN_PORT:-22}" \
SSH_LOG_LEVEL="${SSH_LOG_LEVEL:-INFO}" \
USER="$USER" \
envsubst '${SSH_LISTEN_PORT} ${SSH_LOG_LEVEL} ${USER}' < /etc/templates/sshd_config > /etc/ssh/sshd_config

# Seed initial app.ini if missing
if [ ! -f "${GITEA_CUSTOM}/conf/app.ini" ]; then
  APP_NAME="${APP_NAME:-Gitea: Git with a cup of tea}" \
  RUN_MODE="${RUN_MODE:-prod}" \
  DOMAIN="${DOMAIN:-localhost}" \
  SSH_DOMAIN="${SSH_DOMAIN:-localhost}" \
  HTTP_PORT="${HTTP_PORT:-3000}" \
  ROOT_URL="${ROOT_URL:-}" \
  DISABLE_SSH="${DISABLE_SSH:-false}" \
  SSH_PORT="${SSH_PORT:-22}" \
  SSH_LISTEN_PORT="${SSH_LISTEN_PORT:-22}" \
  LFS_START_SERVER="${LFS_START_SERVER:-false}" \
  DB_TYPE="${DB_TYPE:-sqlite3}" \
  DB_HOST="${DB_HOST:-localhost:3306}" \
  DB_NAME="${DB_NAME:-gitea}" \
  DB_USER="${DB_USER:-root}" \
  DB_PASSWD="${DB_PASSWD:-}" \
  INSTALL_LOCK="${INSTALL_LOCK:-false}" \
  DISABLE_REGISTRATION="${DISABLE_REGISTRATION:-false}" \
  REQUIRE_SIGNIN_VIEW="${REQUIRE_SIGNIN_VIEW:-false}" \
  SECRET_KEY="${SECRET_KEY:-}" \
  envsubst < /etc/templates/app.ini > "${GITEA_CUSTOM}/conf/app.ini"
fi

# Apply GITEA__SECTION__KEY overrides to app.ini
/usr/local/bin/environment-to-ini --config "${GITEA_CUSTOM}/conf/app.ini"

if [ "$(id -u)" -eq 0 ]; then
  chown -R "${USER_UID}:${USER_GID}" /data/git/.ssh "${GITEA_CUSTOM}/conf" "${GITEA_CUSTOM}/log"
  chown "${USER_UID}:${USER_GID}" /data /data/git /data/gitea
  chown -R 0:0 /data/ssh
fi

# If explicit command provided, execute it
if [ $# -gt 0 ]; then
  exec "$@"
fi

# Start OpenSSH unless disabled
SSHD_PID=""
if [ "${DISABLE_SSH:-false}" != "true" ] && [ "${GITEA__server__DISABLE_SSH:-false}" != "true" ]; then
  /usr/sbin/sshd -t -f /etc/ssh/sshd_config
  /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config &
  SSHD_PID=$!
fi

# Start Gitea web server as non-root git user (compatible with no-new-privileges:true)
cd /app/gitea
if [ "$(id -u)" -eq 0 ]; then
  setpriv --reuid="$USER_UID" --regid="$USER_GID" --init-groups \
    env HOME=/data/git USER="$USER" GITEA_WORK_DIR="$GITEA_WORK_DIR" GITEA_CUSTOM="$GITEA_CUSTOM" \
    /usr/local/bin/gitea web &
else
  /usr/local/bin/gitea web &
fi
GITEA_PID=$!

shutdown_all() {
  [ -n "$SSHD_PID" ] && kill -TERM "$SSHD_PID" 2>/dev/null || true
  kill -TERM "$GITEA_PID" 2>/dev/null || true
  wait "$GITEA_PID" 2>/dev/null || true
  [ -n "$SSHD_PID" ] && wait "$SSHD_PID" 2>/dev/null || true
}
trap shutdown_all TERM INT

if [ -n "$SSHD_PID" ]; then
  wait -n "$GITEA_PID" "$SSHD_PID"
else
  wait "$GITEA_PID"
fi
STATUS=$?
shutdown_all
exit "$STATUS"
