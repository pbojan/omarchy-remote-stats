# ADR-009: Poll the servers in a plugin service

- **Status:** accepted
- **Date:** 2026-10-24

## Context

Omarchy creates one bar per monitor, and each bar creates its own instance
of the bar widget. On a machine with 2 monitors, a widget that polls would
poll each server twice. Omarchy also has a `service` plugin kind: the shell
creates one instance for the whole desktop, and a widget gets it with
`bar.shell.serviceFor("<plugin id>")`. The third-party Notification Center
plugin uses this pattern for the same reason.

## Options

1. **Poll in the bar widget**.
   \+ one QML file less.
   − one poll per server per monitor; each panel can show different data.
2. **Poll in a service** (`src/Service.qml`).
   \+ one poll per server; all panels show the same poll results.
   − the widget must find the service, and the shell can load the service
   after the widget.
3. **Poll in a separate process**, for example a systemd user timer that
   writes a file.
   \+ polls also without the shell.
   − a second thing to install and run; the user wants everything in the
   plugin.

## Decision

We use **a service**, because it polls each server once and keeps the plugin
in one folder.

## Consequences

- Good: the service owns the config file, the `ssh` processes, the poll
  results and the status of each server. The widget only shows them.
- Good: the service builds the add-server test's command from the poll
  command, so the test checks what the service will run. The test only
  logs in anew instead of using the shared connection (ADR-006).
- Bad: the widget looks for the service every 200 ms until the shell has
  loaded it.
- Bad: the service has no settings from the widget. Settings for polling go
  in the config file (ADR-008).
