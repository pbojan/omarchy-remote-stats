# ADR-008: Keep settings and servers in one config file

- **Status:** accepted
- **Date:** 2026-10-24

## Context

The panel adds and removes servers (ADR-004). Each server has a name, a
target (`user@host:port`) and a key path. The poll interval must also be
configurable, without new UI. Omarchy widget settings support only
`string`, `integer`, `boolean`, `enum`, `path` and `multiselect` fields, not
a list of objects. Omarchy 4.5.0rc1 shows no settings window for plugins;
`omarchy bar set <id> <key> <value>` writes a widget setting to
`shell.json`. A widget setting reaches the bar widget only, not the service
that polls (ADR-009).

## Options

1. **One config file** `~/.config/omarchy/remote-stats/config.json` with a
   `settings` object (the interval and later settings) and the servers.
   \+ any structure; the service reads it directly; the user edits it or
   runs `remote-stats`.
   − the plugin validates the file itself.
2. **Widget settings**: the interval as a setting, the servers as one string
   setting with JSON inside.
   \+ uses the built-in settings storage.
   − the widget must pass both to the service; a JSON string is unreadable
   in a settings window, which can also break it.
3. **`~/.ssh/config` aliases only**: each server is a `Host` block, and
   the interval is a widget setting.
   \+ no new file.
   − the plugin ignores `~/.ssh/config` (ADR-005), so it cannot connect
   through an alias; the user also wants a free name and a plain
   `user@host:port` target.

## Decision

We use **one config file**, because the server list is structured data that
widget settings cannot hold, and the service reads one file for everything.

## Consequences

- Good: the file holds no secrets: names, targets and key paths only.
- Good: the service watches the file, so a change from the panel, the
  `remote-stats` command or an editor applies in about 1 s.
- Good: more settings can go in the file later: the critical threshold, the
  stale time and the hidden disks (ADR-003).
- Good: the open rows are in the file too (`"open": true` on a server), so
  the panels on all monitors share them and a reload keeps them.
- Bad: the panel writes the file when a row opens or closes, so a hand edit
  in progress can race with a click. The service does not write a file
  that is not valid JSON.
- Bad: the plugin must validate the file on every read. It is untrusted
  input. While the file is not valid JSON, the service keeps the last good
  version, and the panel says so.
- Bad: FileView cannot watch a file that does not exist. The service writes
  the default file when it is missing at start, but not later: Vim and
  Neovim save by renaming the file away, and the defaults would replace the
  user's file.
