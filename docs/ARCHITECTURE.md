# Native Omarchy plugin architecture

## Goal

Provide a native Omarchy overlay (`acme.lexicon`) for offline word lookup, live filter controls, result selection, definitions, and thesaurus browsing inside `omarchy-shell`.

## Omarchy shell integration

The Omarchy shell runs as one long-lived Quickshell process (`omarchy-shell`). User plugins live under `~/.config/omarchy/plugins/<id>/` and are registered in `~/.config/omarchy/shell.json`.

Key conventions:

- Each plugin directory ships a `manifest.json` and QML entry points.
- Third-party plugin IDs use their own namespace (`acme.lexicon`).
- Overlays use `OverlayWindow` inside the existing `omarchy-shell` process.
- Strings live in `i18n/en.json` and are read through `Commons.Translations`, with `textFormat: Text.PlainText` on display text.

## Architecture

### 1. Self-contained plugin bundle (`~/.config/omarchy/plugins/acme.lexicon/`)

`./install.sh` and `PKGBUILD` package the complete plugin and its Python search modules together:

- `manifest.json` — declares `acme.lexicon` with `kinds: ["overlay"]` and `entryPoints.overlay: "LexiconOverlay.qml"`
- `LexiconOverlay.qml` — the keyboard- and mouse-driven overlay UI (`OverlayWindow`, search input, option chips, font row, scale controls, and three-column results view)
- `session.js` — pure session state, 3-entry history ring, rack-letter normalization, UI scale clamping (`0.75–2.0`), and search argument builder
- `search.py` — JSON gateway executed by QML `Process` for word searches (`--query`, `--length`, `--rack`, `--sort`), definitions (`--definition`), and synonyms (`--thesaurus`)
- `lexicon_core.py`, `lexicon_config.py`, `dict_lookup.py`, `sorters.py` — the in-process Python filtering, scoring, configuration, and `dictd` lookup modules bundled alongside `search.py`
- `i18n/en.json` — translated UI strings

### 2. Overlay interaction and state persistence

- **Search & filters**: Typing in `FilterInput` debounces a call to `python3 search.py` and populates the Words column.
- **Rack pool**: Enabling Rack clears `length` to `0` and treats the typed letters as a multiset tile pool, matching any word whose per-letter counts are within the rack counts.
- **Definitions & thesaurus**: Selecting a word in the Words column queries `search.py --definition <word>` (WordNet via local `dictd`) and `search.py --thesaurus <word>` (Moby Thesaurus via local `dictd`). Selecting a synonym updates the Meaning column for that synonym.
- **Appearance**: Font choice (`Theme`, `Sans`, `Serif`, `Mono`, `Writer`) and UI scale (`75%–200%`, adjusted via `−` / `+` buttons or `Ctrl +` / `Ctrl -`) are persisted under `appearance` in `$XDG_STATE_HOME/omarchy-lexicon/overlay.json`, independent of the saved search history ring.
- **Pointer & keyboard routing**: Control chips use `ClickSurface` with `BorderSurface { enabled: false }` beneath a top-level `MouseArea` so presses always reach the control handler while text selection in the search input remains active.
