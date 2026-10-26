# Remote Stats

An Omarchy shell plugin (Quickshell/QML) that shows load, CPU, memory and
disk usage of remote Linux servers in the Omarchy bar. The plugin gets the data
over SSH from Glances on each server. Nothing else runs on the server.

## References

- Requirements: `docs/requirements-v1.md`
- Decisions: `docs/adr/` (ADR-001 to ADR-009)
- Server setup for users: `README.md`
- SSH behaviour and error messages: `docs/research/ssh-tests.md`
- Omarchy source: <https://github.com/basecamp/omarchy>
  - Plugin docs: `manual/32-shell-plugins.md`, `docs/omarchy-shell.md`
  - Shared UI: `shell/Ui/`, `shell/Commons/` (`Style.qml`, `Color.qml`)
  - Reference plugins: `shell/plugins/panels/dropbox/`, `shell/plugins/agents/`

## QML rules

- Take every colour from `Commons.Color` roles, every size from `Style.font`
  and `Style.spacing` tokens or `Style.space(n)`, and the font from
  `Style.font.family`. No fixed px sizes or hex colours.
- Use logical positions, so the layout mirrors in RTL. Mount points and
  `ssh` errors stay left-to-right.
- Show times as clock times (`14:27:31`, `Format.clock()`). No relative
  times, countdowns or ticking text.
- Numbers: whole percent, sizes in GiB or TiB with one decimal, load with
  two decimals, with the locale's decimal separator (`Format.js` with
  `Commons.I18n.formatNumber`).
- Icons are Nerd Font glyphs:

  | Use | Glyph | Code point |
  | --- | --- | --- |
  | Bar, panel header, empty state | `nf-md-server` | U+F048B |
  | Refresh | `nf-md-refresh` | U+F0450 |
  | Add server | `nf-md-plus` | U+F0415 |
  | Remove server | `nf-md-delete_outline` | U+F06CC |
  | Row closed | `nf-md-chevron_right` (RTL: `nf-md-chevron_left`) | U+F0142 (U+F0141) |
  | Row open | `nf-md-chevron_down` | U+F0140 |
  | Close the form, failed check | `nf-md-close` | U+F0156 |
  | Test button, passed check | `nf-md-check` | U+F012C |
  | Running or not-run check | `nf-md-dots_horizontal` | U+F01D8 |
- Reuse components from `qs.Ui` before you write a new one.

## Words

Use one word per concept, in code and docs:

- **server entry**: one item of `servers` in `config.json`: name, target,
  key and `open`.
- **poll result**: what the last polls left for a server: `lastPollMs`,
  `lastOkMs`, `error`, `snapshot` (`Poll.js`). Times are milliseconds; 0
  means never.
- **server**: a server entry with its poll result and `status`. The
  service builds them; the panel shows them.
- **status**: connecting, connected, critical, stale, issue or offline
  (`Status.js`). Only the service computes it.

## Layout

- `manifest.json`: plugin manifest. Entry points: `src/Service.qml`
  (service: reads `config.json`, polls the servers, once for the whole
  shell) and `src/Panel.qml` (bar widget: the bar glyph and the panel).
- `src/`: the two entry points, `i18n/` (strings, next to `Panel.qml` as
  Omarchy expects) and one folder per part:
  - `Service.qml` does the I/O only: the config file and the `ssh`
    processes. Put any rule in `logic/` and test it there.
  - `Panel.qml` finds the service and holds the bar glyph and the panel
    window.
  - `logic/`: no QML, tested in Node. `Target.js` (parse targets),
    `Config.js` (read and edit `config.json`, the defaults), `Poll.js` (the
    ssh command, poll results), `Status.js`, `Format.js` (display text),
    `TestChecks.js` (the add-server test). They start with
    `.pragma library` and share code with `.import "X.js" as X`.
  - `panel/`: `BarButton`, `PanelContent` (the list state: view, cursor,
    remove confirm), `PanelHeader`, `EmptyState`.
  - `row/`: one server in the list. `ServerRow`, `ServerDetails` (the open
    part, by status), `StatusChip`, `MetricRow`, `Meter`.
  - `form/`: `AddServerForm`, `FormField`, `TestCheck`.
  - `common/`: `Theme` (the colours and the font) and `PlainText`.
- A QML file sees only the files in its own folder. It imports the others
  by path: `import "../common"`, `import "../logic/Status.js" as Status`.
  A wrong path shows only in the shell log, so restart the shell after a
  move. Imports go one way: `panel` uses `row` and `form`; every folder
  uses `common` and `logic`.
- Quickshell logs `Module path "…" is outside of the config folder` once
  for each of these folders. The warning is harmless; every plugin outside
  `/usr/share/omarchy/shell` gets it.
- Data goes down as properties, clicks go up as signals. A component never
  reaches into its parent. Every component takes the `Theme` as `theme`
  and the strings as `strings`.
- `bin/remote-stats`: the command line (`setup`, `add`, `remove`,
  `config`). It is not on `PATH` by itself; QML must call it by path, like
  `Qt.resolvedUrl("../bin/remote-stats")`. It passes targets to `ssh` as
  `ssh://<target>` and lets `ssh` report errors. It only reads the host
  from a target, for the default name.
- `server/setup.sh`, `server/remove.sh`: POSIX `sh` scripts that run on
  the server. `bin/remote-stats` sends them over SSH on stdin
  (`ssh … sh -s -- <args> < server/….sh`); nothing is copied to the
  server. Keep them plain `sh`, not bash: servers may not have bash.
- Keep `bin/` and `server/` simple: users are expected to know SSH, so
  check only what is needed and let `ssh` and `glances` report their own
  errors.
- Some facts live in bash and in JS or QML: the defaults, the minimum
  interval, the key-only ssh options, the Glances arguments and the folder
  of the shared connections (`Service.qml`). `test/cli.test.sh` checks that
  the copies match. Change both.
- `test/`: `run` runs everything.
  - `*.test.js`: one Node test per `.js` file. `load.js` loads a file from
    `src/logic/` the way QML does.
  - `cli.test.sh`: the command and the service against a throwaway `sshd`;
    never touches `~/.ssh`. It runs the service in a headless Quickshell
    with `service-harness.qml`. Quickshell imports only from the shell
    file's folder, so the test copies `Service.qml` and `logic/` next to
    the harness.
  - `fixtures/servers.json`: poll results for the Node tests only; the
    plugin has no mock mode.
- `docs/`: requirements, ADRs and research.

## Development

- Config file: `~/.config/omarchy/remote-stats/config.json`: a `settings`
  object (`interval`, `showDisks`) and the servers (ADR-008). The service
  writes the defaults if the file is missing at start.
- All tests: `test/run`. Node tests alone: `node test/<name>.test.js`.
- Install for development (done once): from this folder, link it into the
  shell's plugin folder and enable it.

  ```
  ln -s "$PWD" ~/.config/omarchy/plugins/pbojan.remote-stats
  omarchy plugin enable pbojan.remote-stats --before omarchy.agents
  ```

- Load a change with `omarchy-restart-shell`. The shell's file watcher does
  not follow the symlink. Re-creating the link (`ln -sfn …`) makes the shell
  log `Local plugin changed, reloading`, but it keeps running the old code.
- After a restart, check that the log shows
  `pbojan.remote-stats: widget loaded` (one line per bar),
  `pbojan.remote-stats: polling <n> servers every <s> s` (once, and again
  after each config change) and no QML errors.
- Open the panel: `omarchy-shell pbojan.remote-stats toggle`.
- Check the manifest: `omarchy plugin validate .`
- Shell logs and QML errors: `journalctl --user -t omarchy-shell -f`.
- Ask the user before you install a tool or package.
- Do not take screenshots. The user checks the UI.
- Test SSH against a throwaway `sshd` that runs as the user on
  `127.0.0.1:22222`, with its own host key, `authorized_keys` and
  `known_hosts` in the scratchpad (see `docs/research/ssh-tests.md`). Do not
  change `~/.ssh`. Connect to the user's servers only when the user asks.
- Keep `ControlPath` short (Unix socket limit, about 108 bytes):
  `$XDG_RUNTIME_DIR/remote-stats/%C`.
