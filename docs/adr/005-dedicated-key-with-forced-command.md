# ADR-005: Log in with a dedicated key that can only run Glances

- **Status:** accepted
- **Date:** 2026-10-19

## Context

The plugin runs `ssh` from the Omarchy shell process. That process has no
terminal, so `ssh` cannot ask for a passphrase or a password. It also has no
`SSH_AUTH_SOCK`: on the test machine the agent comes from `keychain` in
`~/.bashrc`, so only terminals see it. A key with a passphrase therefore
works only after the user unlocks it in a terminal, and never right after
boot. The plugin polls each server every 30 s, unattended.

## Options

1. **Dedicated key, no passphrase, forced command**: one key for the
   plugin. Each server lists it in `authorized_keys` with
   `restrict,command="<glances> …"`.
   \+ works right after boot; a stolen key can only read stats.
   − one `authorized_keys` line to add on each server.
2. **Personal key through the user's agent**: the plugin finds the agent
   socket (for example `~/.keychain/<host>-sh`).
   \+ no server setup where the user already has access.
   − no data until the user unlocks the key; a full-shell key in use for
   unattended polling.
3. **Fixed system agent** (`ssh-agent.socket` plus `IdentityAgent`).
   \+ every program sees the same agent.
   − changes SSH for the whole machine; same unlock gap as option 2.

## Decision

We use **a dedicated key with a forced command**, because it works without
an unlocked agent and limits a stolen key to reading stats.

## Consequences

- Good: the server runs only the fixed Glances command for this key. A test
  showed that `id`, a different command and `-tt` all return Glances JSON.
- Good: `restrict` blocks port, agent and X11 forwarding and the pty.
- Good: the forced command uses the absolute Glances path, so the server's
  `PATH` does not matter.
- Bad: the key file has no passphrase. Anyone who copies it can read the
  stats of every server that trusts it.
- Bad: the user adds one line to `authorized_keys` on each server. The
  README has the steps.
- Good: the plugin passes `-F none -i <key> -o IdentitiesOnly=yes
  -o IdentityAgent=none`, so `ssh` offers no other key. A test showed that
  without `-F none`, a key from `~/.ssh/config` logs in when the server
  refuses the plugin key, and an agent key named there is offered first.
- Bad: `~/.ssh/config` does not apply, so the target cannot be a host
  alias, and options such as `ProxyJump` do not work.
