# Remote Stats v1 requirements

Remote Stats v1 shows load, CPU, memory and disk usage of one or more Linux
servers in the Omarchy bar. The plugin gets the data over SSH from Glances,
which is installed on each server. Nothing else runs on the server.

Reader: whoever builds or reviews v1 of the plugin.

Decisions behind this spec:

- [ADR-001: Use Glances as the metrics source](adr/001-use-glances-as-metrics-source.md)
- [ADR-002: Fetch a Glances JSON snapshot over SSH on each poll](adr/002-fetch-glances-snapshot-over-ssh.md)
- [ADR-003: Deduplicate disks in the plugin](adr/003-deduplicate-disks-in-plugin.md)
- [ADR-004: Use one bar widget for all servers](adr/004-one-bar-widget-for-all-servers.md)
- [ADR-005: Log in with a dedicated key that can only run Glances](adr/005-dedicated-key-with-forced-command.md)
- [ADR-006: Reuse one SSH connection per server](adr/006-reuse-one-ssh-connection-per-server.md)
- [ADR-007: Trust host keys on first use](adr/007-trust-host-keys-on-first-use.md)
- [ADR-008: Keep settings and servers in one config file](adr/008-one-config-file.md)
- [ADR-009: Poll the servers in a plugin service](adr/009-poll-in-a-service.md)

Test results that support them: [Glances CLI tests](research/glances-cli-tests.md),
[SSH tests](research/ssh-tests.md).

## Terms

- **Server**: a Linux machine that the plugin monitors.
- **Poll**: one SSH call that gets one snapshot from one server.
- **Snapshot**: the JSON that one Glances run prints.
- **Disk**: one filesystem entry in the snapshot (`fs[]`).
- **Target**: where the plugin connects, written `user@host:port`.
- **Remote Stats key**: the SSH key that the plugin uses, by default
  `~/.ssh/remote_stats_ed25519`. It has no passphrase.

## Data points

| Data point | Unit | Glances field |
| --- | --- | --- |
| Server name | text | none: the name in `config.json`. Without a name, `remote-stats add` and the panel use the host part of the target. |
| Distribution | text | `system.linux_distro` |
| Load average, 1 min | number | `load.min1` |
| Load average, 5 min | number | `load.min5` |
| Load average, 15 min | number | `load.min15` |
| CPU cores | count | `load.cpucore` |
| CPU used | % (0–100), average of all cores | `cpu.total` |
| Memory total | bytes | `mem.total` |
| Memory used | bytes (total − available) | `mem.used` |
| Memory used | % | `mem.percent` |
| Disk mount point | path | `fs[].mnt_point` |
| Disk total | bytes | `fs[].size` |
| Disk used | bytes | `fs[].used` |
| Disk used | % | `fs[].percent` |

The plugin MUST use `fs[].percent` as given. Do not calculate it as
used ÷ size. Glances calculates used ÷ (used + free), which excludes reserved
blocks. This is the same value that `df` shows.

Out of scope for v1: network, swap, temperatures, processes, history,
alerts and hiding single disks.

## Server status

The service gives each server one status. The first row that matches
wins, so an unreachable server never shows old values as current. The bar
glyph shows a dot in `urgent` while any server is Offline, Issue or
Critical.

| Status | When | The open row shows |
| --- | --- | --- |
| Offline | The last poll failed with an SSH error (`ssh` exit code 255) | The `ssh` error as is, and `Last seen <time>` or `Never connected` |
| Issue | The last poll failed on the server: no `glances` command (exit code 127), no answer within 20 s (124), or no snapshot (any other code, also 0) | `Glances not installed`, `No answer within 20 s`, or `Glances printed no snapshot` with the Glances error as is; and a hint |
| Connecting | No poll has finished yet | CPU and Memory with `–`, empty meters, `Waiting for the first poll` |
| Stale | No good poll for 5 poll intervals (150 s at the default 30 s) | The last data points, and `No answer since <time>` in `urgent` |
| Critical | CPU, memory or a disk is at 90 % or more | The data points, with the critical values in `urgent` |
| Connected | The last poll is good | The data points |

## Constraints

- The plugin MUST get data with one SSH command per poll. It MUST pass the
  arguments as a list, never through a shell:

  ```
  timeout 20 \
  ssh -F none -T -i <key> -o IdentitiesOnly=yes -o IdentityAgent=none \
      -o BatchMode=yes -o ConnectTimeout=5 \
      -o StrictHostKeyChecking=accept-new \
      -o ControlMaster=auto -o ControlPersist=300 \
      -o ControlPath=$XDG_RUNTIME_DIR/remote-stats/%C \
      -o ServerAliveInterval=15 -o ServerAliveCountMax=2 \
      -- ssh://<user>@<host>:<port> \
      glances --disable-check-update \
      --disable-plugin all --enable-plugin system,cpu,mem,load,fs \
      --stdout-json system,cpu,mem,load,fs
  ```

  The server's forced command (ADR-005) replaces the command at the end.
  The plugin sends it anyway, so a server without a forced command also
  works.
- The server setup MUST be limited to the Glances package and one
  `authorized_keys` line. The plugin MUST NOT need a daemon or an open port
  on the server.
- The plugin MUST put `--` before the target, and MUST refuse a host that
  starts with `-` (see [SSH tests](research/ssh-tests.md)).
- The plugin MUST NOT ask for a password or a passphrase. `BatchMode=yes`
  makes SSH fail instead of prompting.
- The plugin MUST log in with its key only. It MUST NOT read `~/.ssh/config`
  (`-F none`) or use the SSH agent (`IdentityAgent=none`). A key named in
  `~/.ssh/config` or held by the agent would otherwise log in when the
  server refuses the plugin key, with a full shell instead of the forced
  command. A test showed both cases.
- The plugin MUST NOT start a poll for a server while the previous poll for
  that server still runs.
- A poll MUST end after 20 s (`timeout 20`), so a Glances that hangs on the
  server cannot stop the polls of that server for good.
- The poll interval MUST default to 30 s and MUST NOT be less than 5 s.
  One snapshot takes about 2.4 s. The user sets it in the config file.
- One service polls all servers, once for all monitors (ADR-009).
- The plugin MUST NOT show two disks with the same `device_name`. See
  ADR-003.
- The UI MUST take every colour from `Commons.Color` roles, every size
  from `Style.font` and `Style.spacing` tokens, and the font from
  `Style.font.family`. It MUST NOT contain fixed px sizes or hex colours.
- The bar widget MUST work in top, bottom, left and right bars.

## Add a server

The user adds a server in the panel with a form. It has 3 fields:

| Field | Required | Default | Rule |
| --- | --- | --- | --- |
| Target | yes | — | `host`, `user@host`, `host:port` or `user@host:port`. IPv6 hosts go in brackets: `user@[fe80::1]:22`. |
| Name | yes | the host part of the target | Free text, shown in the panel. Unique in the server list. |
| Key | yes | `~/.ssh/remote_stats_ed25519` | Path to a private key without a passphrase. |

Target rules:

- If the target has no user, `ssh` uses the local user name.
- The host is a host name or an address, not a `~/.ssh/config` alias.
- If the target has no port, the port is 22.
- The host MUST contain only letters, digits, `.`, `-` and `_`, or be an
  IPv6 address in brackets. It MUST NOT start with `-`.

The form checks the fields as you type and shows each error under its
field. The error texts are in `src/i18n/en.json` (`form.err.*`).

The form has a **Test** button. Test needs a valid target. The test runs
these checks in order and stops at the first failure. The checks after a
failure show as not run.

| # | Check | Fails when | Detail and hint on failure |
| --- | --- | --- | --- |
| 1 | Target valid | the target rules above fail | — |
| 2 | Key OK | the key path is empty, the file is missing, or `ssh-keygen -y -P "" -f <key>` fails | The `ssh-keygen` error; `hint.key` |
| 3 | Server answers | exit code 255 with `Connection refused`, `timed out`, `No route to host`, `Could not resolve hostname` or `REMOTE HOST IDENTIFICATION HAS CHANGED` | The `ssh` error as is; `hint.server` or `hint.hostkey` |
| 4 | Key accepted | exit code 255 with `Permission denied` | The `ssh` error as is; `hint.auth` |
| 5 | Glances found | exit code 127, no answer within 20 s (124), or no JSON with `cpu`, `mem`, `load` and `fs` on stdout (any other code) | The Glances error as is; `hint.glances`, `hint.timedOut` or `hint.glancesFailed` |

Test runs `ssh-keygen -y -P "" -f <key>` for check 2. If that passes, it
runs one poll, with the same command as the service, for checks 3 to 5.
The poll MUST log in anew (`-o ControlPath=none`): a shared connection to
the same target would answer without offering the key in the form.

A passed check 3 shows `host:port` under it. A passed check 5 shows the
server's hostname and CPU %. It shows no Glances version: the forced
command (ADR-005) runs only the snapshot, which has no version field.

**Save** writes the server to the server file. Save needs three valid
fields, not a passed test. After a passed test, Save gets the control fill.
A saved server starts in the Connecting state.

### Config file

The plugin stores its settings and the server list in
`~/.config/omarchy/remote-stats/config.json` (ADR-008):

```json
{
  "version": 1,
  "settings": { "interval": 30, "showDisks": true },
  "servers": [
    { "name": "web1", "target": "deploy@192.168.2.20:22", "key": "~/.ssh/remote_stats_ed25519" }
  ]
}
```

- `settings.interval` is the poll interval in seconds. The plugin uses 30
  when the value is missing and 5 when it is less than 5.
- `settings.showDisks: false` hides the disk rows in the panel. A disk at
  90 % or more still marks its server Critical. Default: `true`.
- `remote-stats config <setting> <value>` changes a setting and MUST refuse
  a value outside these rules.
- The plugin MUST validate every entry with the rules above when it reads
  the file, and MUST skip an entry that fails or repeats a name. The panel
  and the log MUST name each skipped entry and the reason.
- If the file is not valid JSON, the plugin MUST keep the last good
  settings and servers, keep polling, and say so in the panel. It MUST NOT
  write the file then.
- The plugin MUST apply a change to the file without a shell restart.
- If the file is missing at start, the plugin MUST write it with the
  defaults. If it goes missing later, the plugin MUST NOT write it: Vim and
  Neovim save by renaming the file away and writing a new one.
- The file MUST NOT contain passwords or key material.
- `open: true` on a server marks its row as open in the panel. The panel
  writes it when the user opens or closes the row. A change to `open` MUST
  NOT restart the polls.

## Acceptance criteria

- [ ] **Scenario: Show stats for a reachable server**
  - **Given** server `web1` is in the plugin config
  - **And** `ssh web1 glances --version` prints version 4.5.8
  - **When** a poll for `web1` completes
  - **Then** the plugin shows `web1` with load 1/5/15 min, CPU %, memory
    used/total/% and every disk with used/total/%
  - **And** each value equals the matching field in that poll's snapshot

- [ ] **Scenario: Show one disk for btrfs subvolumes**
  - **Given** the snapshot has 4 disks with `device_name`
    `/dev/mapper/root`, mounted at `/`, `/home`, `/var/log` and
    `/var/cache/pacman/pkg`
  - **When** the plugin shows the disks
  - **Then** it shows 1 disk, mounted at `/`

- [ ] **Scenario: Server is not reachable**
  - **Given** `ssh web1` fails with exit code 255
  - **When** a poll for `web1` completes
  - **Then** the row for `web1` shows the `Offline` chip
  - **And** the open row shows the SSH error text as is

- [ ] **Scenario: Glances is not installed on the server**
  - **Given** the poll for `web1` prints
    `bash: line 1: /usr/bin/glances: No such file or directory` and exits
    with code 127
  - **When** a poll for `web1` completes
  - **Then** the row for `web1` shows the `Issue` chip
  - **And** the open row shows `Glances not installed`

- [ ] **Scenario: Previous poll still runs**
  - **Given** a poll for `web1` started 12 s ago and has not finished
  - **When** the next poll for `web1` is due
  - **Then** the plugin does not start a second SSH process for `web1`

### Add a server

- [ ] **Scenario: Add a server that passes the test**
  - **Given** `192.168.2.20` accepts `~/.ssh/remote_stats_ed25519` for
    user `deploy`
  - **When** I enter target `deploy@192.168.2.20:22`, name `web1`, and press
    Test
  - **Then** all 5 checks pass and the test header shows `Passed`
  - **And** Save adds `web1` to `config.json` and to the panel list, in the
    Connecting state

- [ ] **Scenario: Key has a passphrase**
  - **Given** `~/.ssh/id_ed25519` has a passphrase
  - **When** I press Test with key `~/.ssh/id_ed25519`
  - **Then** check 2 `Key OK` fails with the `ssh-keygen` error
  - **And** the plugin does not start `ssh`

- [ ] **Scenario: Server does not accept the key**
  - **Given** `192.168.2.20` has no `authorized_keys` line for the plugin
    key
  - **When** I press Test with target `deploy@192.168.2.20`
  - **Then** check 4 `Key accepted` fails with
    `deploy@192.168.2.20: Permission denied (publickey).`
  - **And** the hint says
    `Add remote_stats_ed25519.pub to ~/.ssh/authorized_keys of deploy on the server.`

- [ ] **Scenario: Remove a server in the panel**
  - **Given** `web1` is in `config.json`
  - **When** I press Remove on the row for `web1` and confirm
  - **Then** the plugin removes `web1` from `config.json` and from the list
  - **And** the Remote Stats key line stays on the server. `remote-stats remove`
    removes both.

- [ ] **Scenario Outline: Reject a bad target**
  - **When** I type target `<target>`
  - **Then** the Target field shows `<error>`
  - **And** Test is disabled

  | target | error |
  | --- | --- |
  | `-oProxyCommand=id` | `Host must not start with -` |
  | `deploy@` | `Host is missing` |
  | `deploy@host:99999` | `Port must be 1–65535` |
  | `deploy@host name` | `Host may only use letters, digits, . - _ (IPv6 in [brackets])` |

## Open questions

- Glances 4 or later is the minimum, because we tested 4.5.8. Unknown:
  whether 3.2.7 to 3.x work. The changelog adds `--stdout-json` and
  "disable all plugins" in 3.2.7, but we have not checked if the JSON
  field names are the same in 3.x.
