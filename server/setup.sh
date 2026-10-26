#!/bin/sh
#
# Runs on the server. `remote-stats setup` sends it over SSH:
#
#   ssh ssh://user@host:port sh -s -- <key type> <key> < server/setup.sh
#
# Adds the Remote Stats key to ~/.ssh/authorized_keys with a forced command,
# so the key can run one Glances snapshot and nothing else. An older line for the
# same key is replaced. Every other line stays as it is.

set -eu

key_type="$1"
key="$2"
authorized_keys="$HOME/.ssh/authorized_keys"


# 1. Find Glances: on PATH, or where pipx, pip in a venv and Homebrew put
#    it. Step 2 saves the path in the key line, so polls never search.

glances_path=""

for candidate in \
  "$(command -v glances || true)" \
  "$HOME/.local/bin/glances" \
  "$HOME/.venv/bin/glances" \
  "/home/linuxbrew/.linuxbrew/bin/glances"
do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    glances_path="$candidate"
    break
  fi
done

if [ -z "$glances_path" ]; then
  echo "Glances is not installed on $(hostname)." >&2
  echo "Looked on PATH and in ~/.local/bin, ~/.venv/bin and /home/linuxbrew/.linuxbrew/bin." >&2
  echo "Install it first: https://github.com/nicolargo/glances" >&2
  echo "If it is somewhere else, link it: sudo ln -s /path/to/glances /usr/local/bin/glances" >&2
  exit 1
fi

echo "Found Glances: $glances_path"


# 2. Build the line. `restrict` turns off the terminal and all forwarding;
#    `command=` makes the server run the snapshot, whatever the client asks.

# The same arguments as GLANCES_ARGS in src/logic/Poll.js; test/cli.test.sh
#    checks that they match.
glances_args="--disable-plugin all --enable-plugin system,cpu,mem,load,fs --stdout-json system,cpu,mem,load,fs"
snapshot="$glances_path $glances_args"
key_line="restrict,command=\"$snapshot\" $key_type $key remote-stats"


# 3. Back up authorized_keys, then write it again: every line except an older
#    one for this key, plus the new line.

umask 077
mkdir -p "$HOME/.ssh"
touch "$authorized_keys"

backup="$authorized_keys.bak-$(date +%Y%m%d-%H%M%S)"
cp "$authorized_keys" "$backup"

grep -vF "$key" "$backup" > "$authorized_keys.new" || true
echo "$key_line" >> "$authorized_keys.new"
mv "$authorized_keys.new" "$authorized_keys"

echo "Added the Remote Stats key to $authorized_keys (backup: $backup)"
