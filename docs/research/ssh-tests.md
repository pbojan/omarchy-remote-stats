# SSH tests

The SSH setup from ADR-005 to ADR-007 works end to end: the forced command
holds, one connection serves many polls, and every failure has its own
message. These tests ran on 2026-10-19 with OpenSSH 10.6p1 and Glances
4.5.8.

## Test setup

The tests used a throwaway `sshd` that ran as the normal user on
`127.0.0.1:22222`. It had its own host key, `authorized_keys` and
`known_hosts` in a temporary folder, so `~/.ssh` stayed unchanged. The
`authorized_keys` line came from the README procedure, with `bash -c` in
place of `ssh user@host`.

## Results

| Test | Result |
| --- | --- |
| First poll to a new host | `Warning: Permanently added '[127.0.0.1]:22222' (ED25519)…`, then JSON. 2.76 s. |
| Second poll, same master | JSON. 2.59 s. |
| Client asks for `id; cat /etc/hostname` | Glances JSON. The forced command runs. |
| Client asks for a pty (`-tt`) | Glances JSON. |
| 5 polls in total | sshd log: 1 `Accepted publickey`, 5 sessions, each `forced-command (key-option)`. |
| `from="127.0.0.1",restrict,command=…`, client on 127.0.0.1 | JSON, exit code 0. |
| `from="192.168.2.0/24",restrict,command=…`, client on 127.0.0.1 | Refused, exit code 255. |

## Errors the plugin must tell apart

| Case | Exit code | Output |
| --- | --- | --- |
| Wrong key | 255 | `user@host: Permission denied (publickey).` |
| Nothing listening on the port | 255 | `ssh: connect to host 127.0.0.1 port 22223: Connection refused` |
| Host not reachable (5 s timeout) | 255 | `ssh: connect to host 10.255.255.1 port 22: Connection timed out` |
| Host key changed | 255 | `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` |
| Glances not found on the server | 127 | `bash: line 1: /usr/local/bin/glances: No such file or directory` |

## Findings

- `ControlPath` failed with `ControlPath too long` for a path of more than
  about 108 bytes. `$XDG_RUNTIME_DIR/remote-stats/%C` is 69 bytes.
- A host value of `-oProxyCommand=echo INJECTED` without `--` ran the proxy
  command. With `--` before the host, `ssh` refused it:
  `hostname contains invalid characters`.
