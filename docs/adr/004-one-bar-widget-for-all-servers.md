# ADR-004: Use one bar widget for all servers

- **Status:** accepted
- **Date:** 2026-10-19

## Context

The plugin monitors one or more servers. The bar has little space, and a
vertical bar is only about 2 glyphs wide. Omarchy widget settings support
`string`, `integer`, `boolean`, `enum`, `path` and `multiselect` fields, but
no list of objects.

## Options

1. **One widget for all servers**: one glyph plus an urgent dot; the panel
   lists all servers.
   \+ constant bar width for any number of servers; fits a vertical bar.
   − no per-server values in the bar; the server list needs its own storage.
2. **One widget per server** (`allowMultiple: true`): name plus 3 mini
   meters per widget.
   \+ values visible without a click; each widget uses the built-in settings.
   − bar width grows with each server; names must shorten in a vertical
   bar.

## Decision

We use **one widget for all servers**, because it keeps the bar small and
works in every bar position with no special layout.

## Consequences

- Good: the bar shows one glyph, whatever the number of servers.
- Good: add and remove happen in the panel, in one place.
- Bad: the user must open the panel to see values.
- Bad: the built-in settings cannot hold the server list. The plugin needs
  its own storage for it.
- Follow-up, done: ADR-008 stores the server list, and the requirements
  define the add-server form.
