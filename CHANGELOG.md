# Changelog

Each version of Remote Stats, newest first. The newest version is the one
in `manifest.json`. Read **Action needed** after an update: it lists what to
do to apply the update.

## 1.0.1 – 2026-11-08

### Fixed

- A server showed "Glances printed no snapshot" when a newer Glances was
  out: Glances printed an upgrade notice after the snapshot. The plugin now
  reads only the snapshot.
- Glances no longer checks PyPI for a new version on each poll
  (`--disable-check-update`).

### Action needed

- Run `remote-stats setup user@host` again for each server, so its key line
  gets the new Glances arguments.

## 1.0.0 – 2026-10-26

Initial release of Remote Stats plugin for Omarchy.

Keep an eye on your servers from the Omarchy bar: load, CPU, memory and
disks at a glance, read over SSH from Glances.

- One bar icon for all servers, with a status per server: connected,
  critical, stale, issue or offline
- Panel with one row per server, details on click, and an add-server form
  that tests the login before you save
- Locked-down SSH: one dedicated key, a forced read-only Glances command, no
  passwords, nothing running on the server between polls
- `remote-stats` command: `setup`, `add`, `remove` and `config`
