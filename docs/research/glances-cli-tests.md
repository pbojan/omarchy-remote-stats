# Glances CLI tests

The JSON snapshot mode (`--stdout-json`) is the only Glances output that gives
clean JSON with disks and needs no server process. These tests ran on
2026-10-18 on the local Omarchy machine (16 cores, 32 GB RAM, btrfs) with
Glances 4.5.8 and psutil 7.2.2. Timings come from GNU `time` 1.10.

## Results

| Test | Wall | CPU (user+sys) | Peak RSS |
| --- | --- | --- | --- |
| `--stdout-json system,cpu,mem,load,fs`, all plugins loaded | 2.41 s | 0.21 s | 56.2 MB |
| Same, with `--disable-plugin all --enable-plugin system,cpu,mem,load,fs` | 2.40 s | 0.16 s | 52.6 MB |
| `--fetch` | 2.14 s | 0.27 s | 58.4 MB |
| `--stdout cpu.total,mem.percent -t 5` for 30 s, all plugins | 30 s | 0.32 s | 58.3 MB |
| Same, with `--disable-plugin all --enable-plugin cpu,mem,load,fs` | 30 s | 0.17 s | 52.3 MB |

## Behaviour of each output mode

- **`--stdout-json <plugins>`** prints one JSON line and exits. When PyPI
  has a newer Glances, it prints a four-line upgrade notice on stdout after
  the JSON line, and still exits with 0 (seen on 2026-11-08: 4.5.8, with
  4.5.9 out). `--disable-check-update` stops the check and the notice.
  `--stop-after` has no effect. A snapshot with system, cpu, mem, load and fs
  is 1,775 bytes. Field selection such as `cpu.total` prints `{}`.
- **`--stdout <plugins or fields>`** streams one `name: value` line per stat
  on each refresh. Fields such as `cpu.total` work. List plugins such as `fs`
  print a Python repr (`[{'device_name': ...}]`), not JSON.
- **`--stdout-csv <plugins or fields>`** streams a header line, then one row
  per refresh. The `fs` columns break: the `options` value (for example
  `rw,relatime,compress=zstd:3`) contains commas and is not quoted.
- **`--fetch`** prints a summary for humans and exits.
- **`-w --disable-webui`** (REST server) did not start:
  `FastAPI import error: No module named 'fastapi'`. It needs the
  `python-fastapi` and `uvicorn` packages.
- With `-t 1`, `cpu.total` repeats the same value for about 2 s. The CPU
  value does not refresh faster than that.

## Disk filtering with a config file

`-C <file>` with an `[fs]` section filters disks:

```
[fs]
show=/,/home
alias=/:Root
```

- `show=` and `hide=` take comma-separated regexes. `alias=` renames a mount
  point.
- `-C` replaces `/etc/glances/glances.conf`. It does not add to it.
- `/etc/glances/glances.conf` sets `[fs] refresh=60`. This affects streaming
  modes only.

## Field checks

- `mem.used` = `mem.total` − `mem.available`:
  32,633,069,568 − 17,351,614,464 = 15,281,455,104.
- `fs[].percent` = used ÷ (used + free), not used ÷ size:
  113,749,274,624 ÷ 246,511,599,616 = 46.1 %.

## Version history

From `/usr/share/doc/glances/NEWS.rst`:

- 3.2.7 added "Json stdout option" (#2060) and "disable all plugins by
  default (or enable an exclusive list)" (#2089).
- 4.3.2 made `--stdout` csv and json work in client/server mode (#3235).
