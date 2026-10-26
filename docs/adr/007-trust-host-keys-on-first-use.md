# ADR-007: Trust host keys on first use

- **Status:** accepted
- **Date:** 2026-10-19

## Context

With `BatchMode=yes`, `ssh` cannot ask whether to trust an unknown host
key, so the first connection to a new server fails with
`Host key verification failed`. The servers are on the user's local
network.

## Options

1. **Trust on first use** (`StrictHostKeyChecking=accept-new`): `ssh` saves
   an unknown key and refuses a changed one.
   \+ no extra step when adding a server.
   − the first connection is not verified.
2. **Show the fingerprint and ask**: the add-server test shows the key
   fingerprint with a Trust button.
   \+ the user verifies the first key.
   − an extra step; most users accept without checking.
3. **Require a prior manual login**: the user runs `ssh` once in a
   terminal.
   \+ no plugin code.
   − easy to forget; the test then fails with an unclear error.

## Decision

We use **trust on first use**, because it removes a step and still refuses
a changed key.

## Consequences

- Good: a test with a new host printed
  `Warning: Permanently added '[127.0.0.1]:22222' (ED25519) to the list of
  known hosts.` and continued.
- Good: a changed key still fails with `REMOTE HOST IDENTIFICATION HAS
  CHANGED`. The plugin MUST show this as an error and MUST NOT fix it on its
  own.
- Bad: the first connection to each server is not verified.
- Bad: the plugin writes to the user's `~/.ssh/known_hosts`.
