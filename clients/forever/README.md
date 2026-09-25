# WoW Forever reference corpus

This snapshot is reference material for porting QUI. Its presence and the TOC
interface declaration do not establish runtime compatibility.

- Client build: **1.60.1.70009**; interface **16001**.
- Source: [Gethe/wow-ui-source, forever](https://github.com/Gethe/wow-ui-source/tree/bd2470aed543f72697a044e989285b6c83e63f73).
- Pinned commit: `bd2470aed543f72697a044e989285b6c83e63f73`.
- Vendored: 2026-09-25; 4,420 files in `framexml/Interface/` and 640 generated
  documentation Lua files in `api-docs/blizzard/`.

`framexml/Interface/` is an exact copy of the pinned upstream `Interface/` tree.
`api-docs/blizzard/` copies its `Blizzard_APIDocumentationGenerated/*.lua` files.
Refresh both destinations and `framexml/version.txt` from the same pinned source,
then update this provenance and regenerate the outputs below. Never replace the
Retail snapshots at `tests/framexml/` or `tests/api-docs/blizzard/` with this client.

From the QUI repository root:

```sh
lua tools/test_taint.lua --update-index --corpus tests/clients/forever/api-docs/blizzard --index tests/clients/forever/api-docs/api-index.lua
lua tools/generate_lua_definitions.lua --docs tests/clients/forever/api-docs/blizzard --out tests/clients/forever/meta --globals none
```

The API index contains taint-related metadata, not every documented API. Use the
raw documentation for API availability and signatures. Both generators fail on
malformed or non-executable documentation rather than silently dropping files.
Their constant placeholders permit documentation loading; they do not recover
numeric enum or constant values for gameplay.

`meta/` is an isolated LuaLS library; the default repository `.luarc.json` continues
to select Retail's root `meta/`. A Forever workspace should select this library
and the handwritten root `meta/ace.lua`, never both generated client libraries.
Forever definitions intentionally omit Retail's permissive `.luacheckrc` globals.
They do not yet provide an audited list of Forever's FrameXML globals, and widget
methods retain the generator's existing permissive common-base model. Neither
LuaLS nor a clean taint analysis proves that a feature is available on this client.

The existing graph tool accepts this corpus as a positional directory, but its
widget resolution currently prefers Mainline/shared definitions. Audit actual
Forever TOC load order before using a generated graph as client-specific evidence;
keep its graph and merged serving graph separate from Retail.

These files remain outside the addon package, production lint and compile checks,
and the root Graphify scan. CI regenerates both clients' indexes and definitions
independently; all existing Retail paths and default commands remain unchanged.
