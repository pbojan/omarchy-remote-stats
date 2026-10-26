# ADR-006: Reuse one SSH connection per server

- **Status:** accepted
- **Date:** 2026-10-19

## Context

The plugin polls each server every 30 s by default (ADR-002). With a new
SSH connection per poll, each server logs 2 logins per minute, which is
2,880 per day in its auth log, and opens a new login session each time. OpenSSH
can share one authenticated connection between many commands
(`ControlMaster`).

## Options

1. **New connection per poll**.
   \+ simplest; no state on the client.
   − 2,880 logins per day per server; a key exchange on every poll.
2. **Shared connection** (`ControlMaster=auto`, `ControlPersist`).
   \+ one login per server; each poll is a new channel on the open
   connection.
   − a control socket per server; a dead master must time out.
3. **One long-running stream**: the server loops and prints a snapshot
   every interval.
   \+ least overhead.
   − needs a shell loop on the server, which the forced command
   (ADR-005) does not allow.

## Decision

We use **a shared connection per server**, because it removes the login on
every poll and works with the forced command.

## Consequences

- Good: a test with 5 polls logged 1 `Accepted publickey` and 5 sessions.
- Good: the plugin uses these options on every call:
  `-o ControlMaster=auto -o ControlPersist=300
  -o ControlPath=$XDG_RUNTIME_DIR/remote-stats/%C
  -o ServerAliveInterval=15 -o ServerAliveCountMax=2`.
- Bad: Unix socket paths are limited to about 108 bytes. The control path
  MUST stay short: `/run/user/1000/remote-stats/` plus 40 hex characters is
  69 bytes.
- Bad: a poll time is still about 2.5 s, because Glances start-up
  dominates, not SSH.
- Bad: `sshd` reads `authorized_keys` once per connection, so a changed
  or removed key line applies only to a new connection. A server that
  stays in the list keeps its connection for good, because a poll every
  30 s never lets it idle for 300 s. A removed server's connection closes
  5 minutes after its last poll, but a server added again within those 5
  minutes polls over the old login. So `remote-stats setup` and
  `remote-stats remove` close the connection (`ssh -O exit`). A key line
  that someone removes by hand keeps working until the connection drops.
- Bad: the socket name `%C` hashes the host, port, user and jump host, not
  the key. Two server entries with the same target share one connection,
  so the second entry's key is never used. We accept this edge case.
- Bad: the add-server test cannot use the shared connection, because then
  it would never offer the key in the form. It logs in anew with
  `-o ControlPath=none`.
