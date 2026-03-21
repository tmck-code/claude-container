#!/bin/bash
set -euo pipefail

# If not running as root, skip remap and exec directly
[ "$(id -u)" -ne 0 ] && exec "$@"

TARGET_UID=$(stat -c '%u' /app)
TARGET_GID=$(stat -c '%g' /app)
CURRENT_UID=$(id -u claude)
CURRENT_GID=$(id -g claude)

if [ "$TARGET_UID" -eq 0 ]; then
  echo "[entrypoint] WARNING: /app is owned by root. Keeping claude at UID $CURRENT_UID." >&2
  TARGET_UID=$CURRENT_UID
  TARGET_GID=$CURRENT_GID
else
  [ "$TARGET_GID" -ne "$CURRENT_GID" ] && groupmod --gid "$TARGET_GID" claude
  # --non-unique allows reusing a UID already present in /etc/passwd
  [ "$TARGET_UID" -ne "$CURRENT_UID" ] && usermod --uid "$TARGET_UID" --non-unique claude
fi

chown -R claude:claude /home/claude
exec gosu claude "$@"
