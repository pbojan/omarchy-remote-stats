# ADR-001: Use Glances as the metrics source

- **Status:** accepted
- **Date:** 2026-10-18

## Context

The plugin shows load, CPU, memory and disk usage of remote Linux servers.
Something on each server must read these values. The user wants to install
at most one package on the server and keep all other logic in the plugin.
The data should be structured, so that the plugin does not parse several
text formats.

## Options

1. **Glances**: Python tool, distro package, prints JSON with
   `--stdout-json`.
   \+ one package; JSON output; selects plugins with `--enable-plugin`.
   − about 52 MB RAM and 2.4 s per run; Python startup on every call.
2. **Beszel**: Go agent plus a hub with a database.
   \+ agent uses about 10–15 MB RAM; history and alerts.
   − needs a hub; the plugin must call the hub API with a login; the API
   "may change in minor releases".
3. **Prometheus node_exporter**: Go exporter on port 9100.
   \+ light; common on servers.
   − always runs as a daemon with an open port; raw counters, so the plugin
   must calculate CPU % from two scrapes.
4. **Plain `/proc` and `df` over SSH**: no package.
   \+ nothing to install; fastest.
   − the plugin parses 4 text formats; CPU % needs two `/proc/stat` reads.
5. **Own daemon**: small binary that prints our JSON.
   \+ exact data.
   − we must build, ship and secure it on every server.

## Decision

We use **Glances**, because it needs one distro package and gives all v1
values as JSON in one command, with no daemon.

## Consequences

- Good: the plugin parses one JSON object per poll.
- Good: the user can add Glances plugins (network, sensors) later without a
  change on the server.
- Bad: each poll starts Python on the server: about 0.16 s CPU and 52 MB RAM
  for 2.4 s.
- Bad: the server needs Glances 4 or later, the version we tested
  (4.5.8). Versions from 3.2.7 have `--stdout-json` and may work, but we
  did not test them.
