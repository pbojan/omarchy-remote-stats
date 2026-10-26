#!/bin/sh
#
# Runs on the server. `remote-stats remove` sends it over SSH:
#
#   ssh ssh://user@host:port sh -s -- <key> < server/remove.sh
#
# Removes the Remote Stats key from ~/.ssh/authorized_keys. Every other line stays
# as it is.

set -eu

key="$1"
authorized_keys="$HOME/.ssh/authorized_keys"


# 1. Nothing to do if the key is not there.

if ! grep -qF "$key" "$authorized_keys" 2>/dev/null; then
  echo "The Remote Stats key is not in $authorized_keys."
  exit 0
fi


# 2. Back up authorized_keys, then write it again without the key's line.

umask 077

backup="$authorized_keys.bak-$(date +%Y%m%d-%H%M%S)"
cp "$authorized_keys" "$backup"

grep -vF "$key" "$backup" > "$authorized_keys.new" || true
mv "$authorized_keys.new" "$authorized_keys"

echo "Removed the Remote Stats key from $authorized_keys (backup: $backup)"
