# ADR-003: Deduplicate disks in the plugin

- **Status:** accepted
- **Date:** 2026-10-18

## Context

Glances lists every mounted filesystem. On a btrfs system each subvolume
shows as a separate disk with the same `device_name` and the same numbers.
On the test machine, `/`, `/home`, `/var/log` and `/var/cache/pacman/pkg`
are all `/dev/mapper/root`. Glances can filter disks with `show=` and
`hide=` in a config file, but `-C` needs that file on the server. ADR-002
allows no config file on the server.

## Options

1. **Deduplicate in the plugin**: the plugin keeps one entry per
   `device_name`.
   \+ nothing on the server.
   − the snapshot still carries all disks (about 280 bytes each).
2. **Glances config file on the server**: `show=` / `hide=` in a file,
   passed with `-C`.
   \+ smaller snapshot.
   − a file to manage on every server; `-C` replaces the system config
   instead of adding to it.
3. **Do nothing**: show every disk.
   \+ no code.
   − btrfs servers show the same disk several times.

## Decision

We deduplicate **in the plugin**, because it keeps the server free of
config files, as ADR-002 requires.

v1 does not hide single disks. `showDisks: false` hides all of them. A
`hideDisks` list in `config.json` can come later (ADR-008).

## Consequences

- Good: a btrfs server shows one disk per device, not one per subvolume.
- Bad: the plugin owns the rule. For each `device_name` it keeps the entry
  with the shortest `mnt_point`.
- Bad, accepted risk: the rule is tested on btrfs only. LVM gives each
  volume its own device name, and a bind mount repeats the device of its
  source, so both should show correctly. ZFS is unknown: the datasets of one
  pool have different names but share the pool's space, so one pool can
  show as several disks with the same free space.
