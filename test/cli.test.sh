#!/usr/bin/env bash
#
# End-to-end test of bin/remote-stats and src/Service.qml against a throwaway
# sshd that runs as
# the current user on 127.0.0.1. Both sides get a fake HOME in a temp folder:
#
# - the client: HOME is set for the command, and a wrapper `ssh` first on PATH
#   adds a test config (test key, temp known_hosts);
# - the server: sshd sets HOME with SetEnv.
#
# ~/.ssh is never read or written. Run: test/cli.test.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-22222}"
S="$(mktemp -d /tmp/rs-test.XXXXXX)"
SERVER_KEYS="$S/server/.ssh/authorized_keys"

cleanup() {
  if [[ -f "$S/sshd.pid" ]]; then kill "$(cat "$S/sshd.pid")" 2> /dev/null || true; fi
  pkill -f "$S/run/remote-stats" 2> /dev/null || true
  rm -rf "$S"
}
trap cleanup EXIT

pass() { echo "ok   $*"; }
die() { echo "FAIL $*" >&2; exit 1; }


# Server: authorized_keys holds the "personal" key and one unrelated line.

mkdir -p "$S/server/.ssh" "$S/client/.ssh" "$S/bin" "$S/run"
ssh-keygen -q -t ed25519 -N "" -f "$S/hostkey"
ssh-keygen -q -t ed25519 -N "" -C personal -f "$S/personal"
cp "$S/personal.pub" "$SERVER_KEYS"
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOtherUnrelatedKeyLineForTheTest other@example" >> "$SERVER_KEYS"

cat > "$S/sshd_config" <<EOF
Port $PORT
ListenAddress 127.0.0.1
HostKey $S/hostkey
AuthorizedKeysFile $SERVER_KEYS
PidFile $S/sshd.pid
UsePAM no
StrictModes no
PasswordAuthentication no
KbdInteractiveAuthentication no
SetEnv HOME=$S/server
EOF
/usr/bin/sshd -f "$S/sshd_config" -E "$S/sshd.log"


# Client: the personal key is the "normal login".

cat > "$S/ssh_config" <<EOF
Host *
  IdentityFile $S/personal
  IdentityAgent none
  UserKnownHostsFile $S/known_hosts
  StrictHostKeyChecking accept-new
EOF
# The plugin passes `-F none`, which replaces this -F (the last -F wins). The
# -o options still apply, because the first value of an option wins, so the
# real ~/.ssh/known_hosts is never written.
printf '#!/bin/sh\nexec /usr/bin/ssh -o UserKnownHostsFile=%s -o IdentityAgent=none -F %s "$@"\n' "$S/known_hosts" "$S/ssh_config" > "$S/bin/ssh"
chmod +x "$S/bin/ssh"

export HOME="$S/client"
export XDG_CONFIG_HOME="$S/client/.config"
export XDG_RUNTIME_DIR="$S/run"
export PATH="$S/bin:$PATH"
CLI="$ROOT/bin/remote-stats"
TARGET="$USER@127.0.0.1:$PORT"
CONFIG="$XDG_CONFIG_HOME/omarchy/remote-stats/config.json"

for _ in 1 2 3 4 5 6 7 8 9 10; do
  ssh -o BatchMode=yes -- "ssh://$TARGET" true 2> /dev/null && break
  timeout 0.3 tail -f /dev/null || true
done


# Safety first: the server side must see the temp HOME, nothing else.

seen="$(ssh -o BatchMode=yes -- "ssh://$TARGET" 'printf %s "$HOME"')"
[[ "$seen" == "$S/server" ]] || die "sshd SetEnv HOME did not apply (got '$seen'); stopping"
pass "server side uses the temp HOME"


out="$(printf 'n\n' | "$CLI" setup "$TARGET" 2>&1)"
grep -q "No shell, no terminal, no forwarding" <<< "$out" || die "setup did not list its steps: $out"
[[ ! -f "$HOME/.ssh/remote_stats_ed25519" ]] || die "setup created the key after 'n'"
[[ "$(grep -c '^restrict,command=' "$SERVER_KEYS")" == 0 ]] || die "setup changed authorized_keys after 'n'"
pass "setup lists its steps and changes nothing without a yes"

out="$(printf 'y\n' | "$CLI" setup "$TARGET" 2>&1)" || die "setup failed: $out"
[[ -f "$HOME/.ssh/remote_stats_ed25519" ]] || die "setup did not create the key"
[[ "$(grep -c '^restrict,command=' "$SERVER_KEYS")" == 1 ]] || die "expected 1 forced-command line"
grep -q ' personal$' "$SERVER_KEYS" || die "setup removed the personal key line"
grep -q 'other@example$' "$SERVER_KEYS" || die "setup removed an unrelated line"
pass "setup creates the key, adds 1 forced-command line, keeps other lines"

out="$(printf 'y\n' | "$CLI" setup "$TARGET" 2>&1)" || die "second setup failed: $out"
[[ "$(grep -c '^restrict,command=' "$SERVER_KEYS")" == 1 ]] || die "second setup left a duplicate line"
ls "$SERVER_KEYS".bak-* > /dev/null 2>&1 || die "setup made no backup"
pass "setup again replaces the line, no duplicate, backup made"

json="$(ssh -T -i "$HOME/.ssh/remote_stats_ed25519" -o IdentitiesOnly=yes -o BatchMode=yes -- "ssh://$TARGET" 'id; echo HACKED' 2> /dev/null)"
jq -e ".cpu" <<< "$json" > /dev/null || die "the Remote Stats key ran something other than Glances"
! grep -q HACKED <<< "$json" || die "the Remote Stats key ran a shell command"
pass "the Remote Stats key runs only the Glances snapshot"

mkdir -p "$S/no-glances"
ln -s "$(command -v hostname)" "$S/no-glances/hostname"
out="$(PATH="$S/no-glances" /bin/sh "$ROOT/server/setup.sh" ssh-ed25519 AAAA 2>&1)" && die "server setup ran without Glances"
grep -q "nicolargo/glances" <<< "$out" || die "no install link when Glances is missing: $out"
pass "server setup stops with a link when Glances is missing"

# A venv install, as in the Glances README: not on PATH, in ~/.venv/bin.
mkdir -p "$S/tools" "$S/venv-home/.venv/bin"
for tool in hostname date cp grep mv mkdir touch; do ln -s "$(command -v "$tool")" "$S/tools/$tool"; done
printf '#!/bin/sh\n' > "$S/venv-home/.venv/bin/glances"
chmod +x "$S/venv-home/.venv/bin/glances"
out="$(HOME="$S/venv-home" PATH="$S/tools" /bin/sh "$ROOT/server/setup.sh" ssh-ed25519 AAAA 2>&1)" || die "server setup did not find the venv Glances: $out"
grep -q "^restrict,command=\"$S/venv-home/.venv/bin/glances " "$S/venv-home/.ssh/authorized_keys" \
  || die "the key line does not use the venv path"
pass "server setup finds Glances in ~/.venv/bin and saves its path in the key line"

"$CLI" add "$TARGET" test-box > /dev/null || die "add failed"
jq -e --arg t "$TARGET" '.servers[] | select(.name == "test-box" and .target == $t)' "$CONFIG" > /dev/null || die "add wrote no entry"
"$CLI" add "$TARGET" test-box > /dev/null 2>&1 && die "add accepted a duplicate name"
pass "add writes the entry and refuses a duplicate name"

"$CLI" config interval 3 > /dev/null 2>&1 && die "config accepted an interval of 3 s"
"$CLI" config showDisks maybe > /dev/null 2>&1 && die "config accepted showDisks maybe"
"$CLI" config colour red > /dev/null 2>&1 && die "config accepted an unknown setting"
"$CLI" config interval 7 > /dev/null || die "config interval 7 failed"
"$CLI" config showDisks false > /dev/null || die "config showDisks false failed"
jq -e '.settings == {interval: 7, showDisks: false}' "$CONFIG" > /dev/null || die "config wrote the wrong settings: $(jq -c .settings "$CONFIG")"
[[ "$("$CLI" config | jq -c .)" == '{"interval":7,"showDisks":false}' ]] || die "config did not print the settings"
pass "config shows and changes interval and showDisks, refuses bad values"

names="$S/names/omarchy/remote-stats/config.json"
XDG_CONFIG_HOME="$S/names" "$CLI" add "deploy@web1.example.org:2222" > /dev/null
XDG_CONFIG_HOME="$S/names" "$CLI" add "root@[fe80::1]:22" > /dev/null
XDG_CONFIG_HOME="$S/names" "$CLI" add "db1" > /dev/null
jq -e '[.servers[].name] == ["web1.example.org", "fe80::1", "db1"]' "$names" > /dev/null \
  || die "add without a name did not use the host: $(jq -c '[.servers[].name]' "$names")"
pass "add without a name uses the host, as the panel does"


# Facts that live in both the command line and the plugin must match.

js() { node -e "const load = require('$ROOT/test/load.js'); console.log($1)"; }

# The ssh command of a poll for $TARGET, one argument per line. Without a
# control folder, it is the add-server test's command.
poll_command() {
  node -e '
    const Poll = require(process.argv[1])("Poll")
    Poll.command({ target: process.argv[2] }, process.argv[3], process.argv[4]).forEach((a) => console.log(a))
  ' "$ROOT/test/load.js" "$TARGET" "$HOME" "$1"
}

# shellcheck source=/dev/null
source <(grep -E '^(key_only_options|min_interval)=' "$ROOT/bin/remote-stats")
[[ "${key_only_options[*]}" == "$(js 'load("Poll").KEY_ONLY_OPTIONS.join(" ")')" ]] \
  || die "bin/remote-stats and Poll.js log in with different key-only options"
[[ "$min_interval" == "$(js 'load("Config").MIN_INTERVAL')" ]] || die "bin/remote-stats and Config.js have different minimum intervals"
[[ "$(grep '^glances_args=' "$ROOT/server/setup.sh" | cut -d '"' -f 2)" == "$(js 'load("Poll").GLANCES_ARGS.join(" ")')" ]] \
  || die "server/setup.sh and Poll.js run Glances with different arguments"
[[ "$(XDG_CONFIG_HOME="$S/defaults" "$CLI" config | jq -cS .)" == "$(js 'JSON.stringify(load("Config").DEFAULT_SETTINGS)' | jq -cS .)" ]] \
  || die "bin/remote-stats and Config.js have different default settings"
pass "the command line and the plugin share ssh options, Glances arguments and defaults"


# The service polls every server in config.json: test-box answers, nothing
# listens on port 1.

"$CLI" add "$USER@127.0.0.1:1" down > /dev/null
# Quickshell imports only from the folder of the shell file, so copy the
# service and its logic/ folder next to the harness.
mkdir -p "$S/qs"
cp "$ROOT/test/service-harness.qml" "$S/qs/shell.qml"
cp -r "$ROOT/src/Service.qml" "$ROOT/src/logic" "$S/qs/"
out="$(QT_QPA_PLATFORM=offscreen timeout 30 qs -p "$S/qs/shell.qml" 2>&1)" || die "service harness failed: $out"
result="$(sed -n 's/.*RESULT //p' <<< "$out")"
jq -e '.settings == {interval: 7, showDisks: false}' <<< "$result" > /dev/null || die "service did not read the settings: $result"
jq -e '.servers[] | select(.name == "test-box") | .error == null and .cpu != null and .status == "connected"' <<< "$result" > /dev/null \
  || die "service got no snapshot from test-box: $result"
jq -e '.servers[] | select(.name == "down") | .error.kind == "ssh" and (.error.message | test("refused")) and .status == "offline"' <<< "$result" > /dev/null \
  || die "service did not report the ssh error for down: $result"
ls "$S/run/remote-stats/" | grep -q . || die "service left no shared connection"
pass "service polls the servers, reports ssh errors, shares the connection"

jq -e '[.servers[].name] == ["test-box", "from-panel"] and .settings.interval == 7 and .servers[0].open == true' "$CONFIG" > /dev/null \
  || die "service add/remove wrote the wrong config: $(cat "$CONFIG")"
pass "service adds, removes and opens servers in config.json, keeps the other settings"

steps="$(sed -n 's/.*STEP //p' <<< "$out")"
step() { jq -c --arg s "$1" 'select(.step == $s)' <<< "$steps"; }
jq -e '.output == "" and .servers == ["test-box", "from-panel"]' <<< "$(step editor-save)" > /dev/null \
  || die "service wrote config.json while an editor saved it: $(step editor-save)"
pass "service leaves config.json alone while an editor saves it"

jq -e '.invalid and .servers == ["test-box", "from-panel"]' <<< "$(step invalid)" > /dev/null \
  || die "service did not keep the last good config: $(step invalid)"
jq -e '(.invalid | not) and .skipped == [{index: 3, name: "bad", reason: "target"}, {index: 4, name: "test-box", reason: "duplicate"}]' \
  <<< "$(step skipped)" > /dev/null || die "service did not report the skipped servers: $(step skipped)"
pass "service keeps the last good config on invalid JSON and reports skipped servers"


# Polls share one connection per server, and sshd reads the forced command
# once per connection. setup must close the connection the service opened,
# so the next poll runs the new forced command.

out="$(printf 'y\n' | "$CLI" setup "$TARGET" 2>&1)" || die "setup failed: $out"
for _ in 1 2 3 4 5; do
  [[ -z "$(ls -A "$S/run/remote-stats/")" ]] && break
  timeout 0.2 tail -f /dev/null || true
done
[[ -z "$(ls -A "$S/run/remote-stats/")" ]] || die "setup left the shared connection open"
pass "setup again closes the shared connection, so the next poll gets the new forced command"

# Open a shared connection again, as a poll does.
mapfile -t shared < <(poll_command "$S/run/remote-stats")
"${shared[@]}" < /dev/null > /dev/null 2>&1 || die "a poll over a new shared connection failed"

# Someone removes the key line by hand. The shared connection still works,
# because sshd read authorized_keys when it logged in (ADR-006). The
# add-server test must log in anew, so the server refuses it.
cp "$SERVER_KEYS" "$S/authorized_keys.keep"
sed -i '/^restrict,command=/d' "$SERVER_KEYS"
"${shared[@]}" < /dev/null > /dev/null 2>&1 || die "no shared connection left to test with"
mapfile -t fresh < <(poll_command "")
out="$("${fresh[@]}" < /dev/null 2>&1)" && die "the add-server test used the shared connection: $out"
pass "the add-server test logs in anew, not over a shared connection"
cp "$S/authorized_keys.keep" "$SERVER_KEYS"


out="$(printf 'n\n' | "$CLI" remove "$TARGET" 2>&1)"
[[ "$(grep -c '^restrict,command=' "$SERVER_KEYS")" == 1 ]] || die "remove changed something after 'n'"
pass "remove does nothing without a yes"

# remove must also close the shared connection: a server added again within
# 5 minutes would otherwise poll over the old login.
out="$(printf 'y\n' | "$CLI" remove "$TARGET" 2>&1)" || die "remove failed: $out"
[[ "$(grep -c '^restrict,command=' "$SERVER_KEYS")" == 0 ]] || die "remove left the forced-command line"
grep -q ' personal$' "$SERVER_KEYS" && grep -q 'other@example$' "$SERVER_KEYS" || die "remove deleted other lines"
jq -e 'any(.servers[]; .name == "test-box") | not' "$CONFIG" > /dev/null || die "remove left the config.json entry"
for _ in 1 2 3 4 5; do
  [[ -z "$(ls -A "$S/run/remote-stats/")" ]] && break
  timeout 0.2 tail -f /dev/null || true
done
[[ -z "$(ls -A "$S/run/remote-stats/")" ]] || die "remove left the shared connection open"
pass "remove deletes the key line and the entry, closes the shared connection, keeps other lines"

# A target that no entry has, such as an alias from ~/.ssh/config.
before="$(cat "$CONFIG")"
out="$(printf 'y\n' | "$CLI" remove "127.0.0.1:$PORT" 2>&1)" || die "remove failed: $out"
grep -q "no server in .* has the target 127.0.0.1:$PORT" <<< "$out" || die "remove did not say that no entry matched: $out"
! grep -q "^Removed 127.0.0.1" <<< "$out" || die "remove said it removed an entry it did not find: $out"
[[ "$(cat "$CONFIG")" == "$before" ]] || die "remove changed config.json for an unknown target"
pass "remove says when no server in config.json has the target"


# The test config names the personal key for every host, as a user's
# ~/.ssh/config can. Now that the server refuses the Remote Stats key, the
# poll must fail, not log in with the personal key. Close the shared
# connections first, so the poll has to log in again.

pkill -f "$S/run/remote-stats" || true
mapfile -t poll < <(poll_command "$S/run/remote-stats")
out="$("${poll[@]}" < /dev/null 2>&1)" && die "the poll logged in with another key: $out"
grep -q "Permission denied" <<< "$out" || die "the poll failed, but not with Permission denied: $out"
pass "the poll uses only the Remote Stats key, not a key from the ssh config"

echo "cli tests passed"
