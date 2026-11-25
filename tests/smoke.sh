#!/usr/bin/env bash
# Smoke test for dgcosenza/gitea: verifies Gitea version, tini PID 1,
# non-root git execution (UID/GID 1000), GITEA__* env-to-ini rendering,
# /api/healthz pass, OpenSSH listening on port 22, and negative healthcheck.
set -euo pipefail

IMAGE="${1:-dgcosenza/gitea:ci-candidate}"
NAME="gitea-ci-smoke-$$"
TMPDATA="$(mktemp -d)"
chmod 777 "$TMPDATA"

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker run --rm --user 0:0 -v "${TMPDATA}:/cleanup" --entrypoint /bin/sh "$IMAGE" -c 'rm -rf /cleanup/* /cleanup/.[!.]*' >/dev/null 2>&1 || true
  rm -rf "$TMPDATA" 2>/dev/null || true
}
trap cleanup EXIT

# 1. Verify official Gitea version output
GITEA_VER="$(docker run --rm --entrypoint /usr/local/bin/gitea "$IMAGE" --version)"
echo "Gitea binary: ${GITEA_VER}"
printf '%s' "$GITEA_VER" | grep -qiE 'gitea version [0-9]+\.[0-9]+\.[0-9]+'

# 2. Boot container with SQLite + GITEA__* env overrides + no-new-privileges
docker run -d --name "$NAME" \
  --security-opt no-new-privileges:true \
  -p 127.0.0.1:13080:3000 \
  -p 127.0.0.1:12223:22 \
  -e USER_UID=1000 \
  -e USER_GID=1000 \
  -e TZ=Etc/UTC \
  -e GITEA__database__DB_TYPE=sqlite3 \
  -e GITEA__database__PATH=/data/gitea/gitea.db \
  -e GITEA__security__INSTALL_LOCK=true \
  -e GITEA__service__DISABLE_REGISTRATION=true \
  -e GITEA__server__START_SSH_SERVER=false \
  -v "${TMPDATA}:/data" \
  "$IMAGE"

# 3. Wait for /api/healthz to return pass
READY=0
for _ in $(seq 1 45); do
  if ! docker ps -q --filter "name=^/${NAME}$" | grep -q .; then
    echo "ERROR: gitea container exited prematurely:" >&2
    docker logs "$NAME" >&2 || true
    exit 1
  fi
  HEALTH="$(docker exec "$NAME" wget -q -O - http://127.0.0.1:3000/api/healthz 2>/dev/null || true)"
  if printf '%s' "$HEALTH" | grep -qE '"status"[[:space:]]*:[[:space:]]*"pass"'; then
    READY=1
    break
  fi
  sleep 2
done
if [ "$READY" -ne 1 ]; then
  echo "ERROR: Gitea /api/healthz did not pass within timeout." >&2
  docker logs "$NAME" >&2 || true
  exit 1
fi
echo "healthz: ${HEALTH}"

# 4. Verify tini PID 1, non-root git Gitea process, and OpenSSH daemon listening on 22
PID1_COMM="$(docker exec "$NAME" cat /proc/1/comm)"
test "$PID1_COMM" = "tini"
docker exec "$NAME" ps -eo user,comm | grep -qE '^git[[:space:]]+gitea$'
docker exec "$NAME" ps -eo comm | grep -qE '^sshd$'

# Verify SSH banner responds on mapped port 12223
BANNER="$(bash -c 'exec 3<>/dev/tcp/127.0.0.1/12223; head -n1 <&3' | tr -d '\r')"
echo "SSH banner: ${BANNER}"
printf '%s' "$BANNER" | grep -q '^SSH-2\.0-OpenSSH'

# Verify GITEA__* env var was written to app.ini
docker exec "$NAME" grep -q 'INSTALL_LOCK = true' /data/gitea/conf/app.ini

# 5. Run exact healthcheck and negative closed-port check
docker exec "$NAME" sh -c "wget -q -O - http://127.0.0.1:3000/api/healthz | grep -q pass"
if docker exec "$NAME" sh -c "wget -q -T 3 -O - http://127.0.0.1:59999/api/healthz | grep -q pass" 2>/dev/null; then
  echo "ERROR: healthcheck unexpectedly passed on closed port 59999" >&2
  exit 1
fi

echo "Smoke test passed (pid1=${PID1_COMM}, ssh=ok, healthz=pass)."
