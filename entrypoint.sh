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
  if [ "$TARGET_GID" -ne "$CURRENT_GID" ]; then
    echo "[entrypoint] Changing claude's GID from $CURRENT_GID to $TARGET_GID" >&2
    groupmod --gid "$TARGET_GID" claude
  fi
  # --non-unique allows reusing a UID already present in /etc/passwd
  if [ "$TARGET_UID" -ne "$CURRENT_UID" ]; then
    echo "[entrypoint] Changing claude's UID from $CURRENT_UID to $TARGET_UID" >&2
    usermod --uid "$TARGET_UID" --non-unique claude
  fi
fi

chown -R $TARGET_UID:$TARGET_GID /home/claude
chmod 777 /usr/bin/claude
exec gosu claude "$@"
