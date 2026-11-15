# Native Omarchy plugin architecture

## Goal

Build a native Omarchy experience that matches the product requirement: a rich, keyboard-first search overlay for word lookup, with live filter controls, result selection, and optional dictionary output.

This project will keep the existing Python CLI as a reusable backend and validation layer, but the end-user product will be a native Omarchy plugin instead of a `walker` shim.

## Research findings from Omarchy

The Omarchy shell runs as one long-lived Quickshell process named `omarchy-shell`. Plugins are discovered from `~/.config/omarchy/plugins/<id>/` and from the first-party shell plugin directories under `$OMARCHY_PATH`.

Important guidance from the Omarchy docs:

- Plugins are directories with a `manifest.json` and QML entry points.
- Plugin IDs must be unique and cannot use the reserved `omarchy.` namespace.
- Plugins run unsandboxed as the current user inside the long-lived shell session.
- Avoid starting a second Quickshell session; keep the plugin inside the shell process.
- Prefer small, focused plugins; use `manifest.json` with `kinds` such as `overlay`, `service`, or `panel` as needed.
- User-installed plugins live under `~/.config/omarchy/plugins/` and hot-reload when files change.

This is a good fit for `omarchy-lexicon`: the search overlay itself should be a native Omarchy `overlay`, while optional background services or clipboard/dictionary hooks remain lightweight and optional.

## Design principles

1. Keep the core logic in Python.
   - The existing `src/lexicon_core.py`, `src/dict_lookup.py`, and config loader are already the reusable engine.
   - QML should not duplicate the dictionary/filtering rules.

2. Keep the UI small and native.
   - Search form, result list, and selected-word details should live in a single overlay designed for fast keyboard input.
   - Avoid building a heavyweight app shell or a multi-window tool.

3. Keep data flow simple.
   - The frontend sends a search request to a Python backend.
   - The backend returns JSON results.
   - The UI renders the result list and copies a selected word to the system clipboard.

4. Keep optional services optional.
   - Dictionary lookup is a secondary feature. Only run it when `dictd` and a dictionary database are available.
   - Do not block search flow if the service is missing.

5. Prefer one plugin, one responsibility.
   - The plugin performs search and selection.
   - The backend performs filtering and dictionary lookup.
   - There is no separate standalone launcher UI.

## Proposed lightweight architecture

### 1. Backend engine

Keep the current Python package as the canonical search engine:

- `src/lexicon_core.py`
  - word loading
  - exact/length/range filters
  - wildcard, substring, regex matching
  - rack-letter validation
  - scoring and sorting
- `src/dict_lookup.py`
  - `dictd`/dictionary lookups
  - synonyms lookup
- `src/lexicon_config.py`
  - config/env handling

This gives us a stable backend that can be reused by both CLI and native plugin UIs.

### 2. Omarchy plugin surface

Plugin directory:

- `~/.config/omarchy/plugins/acme.lexicon/`

Manifest:

- `manifest.json`
- `id`: `acme.lexicon`
- `name`: `Lexicon`
- `version`: `0.1.0`
- `kinds`: `["overlay"]`
- `entryPoints`: { "overlay": "LexiconOverlay.qml" }

This matches Omarchy’s plugin model and keeps the product small and focused.

### 3. Search overlay flow

User action:

- Launch from a keybinding or Omarchy command.

Plugin behavior:

- Open a small overlay.
- Accept typed input for filters and query text.
- Trigger a fast search request to the Python engine.
- Render live results in a narrow, keyboard-friendly list.
- Allow selection with Enter or mouse click.

On selection:

- Copy the chosen word to the clipboard.
- Optionally fetch definition and synonym output in a details panel.
- Optionally present search history or recent lookups.

### 4. IPC and process model

Recommended pattern:

- Use a lightweight Python subprocess launched by the plugin when needed.
- Pass filter arguments as JSON or command-line flags.
- Read back JSON result payloads.
- Keep the plugin in the shell process and avoid spawning a second Quickshell instance.

This is simpler and more robust than trying to port all logic into QML.

## Best-practice constraints

- Never use the reserved `omarchy.` prefix for plugin IDs.
- Keep overlays lightweight and single-purpose.
- Avoid privileged operations; no sudo or root actions in the plugin.
- Use a temp file or stdout JSON contract for IPC, not dense ad hoc shell parsing.
- Keep error states easy to understand: missing word list, missing dictionary service, invalid regex.
- Do not over-engineer beyond the initial release: a single overlay + backend is enough for v1.

## Minimal release plan

### Phase 1: CLI backend validation

- Keep the Python CLI working and tested.
- Validate dictionary fallback behavior and config loading.
- Treat the CLI as the engine and test harness.

### Phase 2: plugin prototype

- Create a user-owned Omarchy plugin directory.
- Add `manifest.json` and `LexiconOverlay.qml`.
- Bind it to a convenient key combo.
- Wire the overlay to the backend Python engine for search results.

### Phase 3: native UX polish

- Add a result panel for word details.
- Add clipboard support and optional dictionary output.
- Improve input state and filter toggles.

### Phase 4: packaging and install docs

- Document how to install the plugin into `~/.config/omarchy/plugins/`.
- Keep packaging simple: install the Python engine and plugin assets to a user-managed plugin path.

## Why this stays lightweight

This design keeps the project focused on the real product requirement without adding unnecessary infrastructure:

- no `walker` wrapper
- no fake menu semantics
- no second Quickshell process
- no complex service bus beyond what the Omarchy shell already provides
- a single Python backend plus a small QML overlay

That matches Omarchy’s own plugin model and keeps the project maintainable while still providing the rich UX users expect.
