# ADR-002: Fetch a Glances JSON snapshot over SSH on each poll

- **Status:** accepted
- **Date:** 2026-10-18

## Context

ADR-001 selects Glances. Glances has three ways to give data to another
machine. The user wants nothing to run on the server between polls: no
daemon, no open port, no config file. The plugin can run any command with
Quickshell's `Process`, as the built-in weather and tailscale plugins do.
Test results are in [Glances CLI tests](../research/glances-cli-tests.md).

## Options

1. **One snapshot over SSH**: `ssh <host> glances --stdout-json …` on every
   poll.
   \+ clean JSON with disks; nothing runs between polls; SSH gives
   authentication and encryption.
   − about 2.4 s per snapshot; Python startup and SSH handshake on every
   poll.
2. **Stream over SSH**: one long `ssh <host> glances --stdout …` session.
   \+ almost no CPU after startup (0.17 s for 30 s).
   − `--stdout` prints disks as a Python repr, not JSON; `--stdout-csv`
   breaks on commas in mount options; `--stdout-json` exits after one
   snapshot, so it cannot stream.
3. **REST server**: `glances -w --disable-webui` on the server, plugin
   polls `/api/4/…`.
   \+ JSON per plugin and per field.
   − a daemon and an open port on every server; needs
   `python-fastapi` and `uvicorn`; needs its own authentication.

## Decision

We use **one snapshot over SSH**, because it is the only option that gives
JSON for all v1 values and runs nothing on the server between polls.

## Consequences

- Good: setup on the server is "install Glances, allow SSH key login".
- Good: SSH does the login and the encryption; the plugin adds neither.
- Bad: the minimum useful poll interval is about 3 s.
- Bad: each poll costs an SSH handshake, unless the connection stays open.
  ADR-006 keeps one connection open per server.
- Bad: a Glances that hangs on the server would keep its poll running for
  good, so `timeout 20` ends each poll. The Glances process stays on the
  server until it finishes, because `sshd` does not stop a command that has
  no terminal. A test showed this.
