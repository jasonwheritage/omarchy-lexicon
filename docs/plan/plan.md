# omarchy-lexicon project plan

## Architecture overview

`omarchy-lexicon` is packaged and delivered as a self-contained native Omarchy overlay plugin (`acme.lexicon`) backed by an embedded Python search engine (`search.py` and `lexicon_core.py`).

### Components

- `plugins/acme.lexicon/manifest.json` — Omarchy plugin manifest (`id: "acme.lexicon"`, `kinds: ["overlay"]`).
- `plugins/acme.lexicon/LexiconOverlay.qml` — Quickshell `OverlayWindow` UI with pattern input, length/rack/sort controls, font selector row, scale controls (`−` / `+` and `Ctrl +/-`), and three-column Words / Meaning / Thesaurus view.
- `plugins/acme.lexicon/session.js` — Session state, 3-entry history ring, rack-letter pool helper, scale clamping, and search argument builder.
- `plugins/acme.lexicon/search.py` — JSON search and dictionary/thesaurus gateway invoked by the QML overlay.
- `src/lexicon_core.py`, `src/lexicon_config.py`, `src/dict_lookup.py`, `src/sorters.py` — Filtering, configuration, scoring, and `dictd` lookup modules bundled into the plugin directory on install.
- `config/default.conf` — Default configuration for wordlist and `dictd` database names.
- `install.sh`, `uninstall.sh`, and `PKGBUILD` — Self-contained plugin installation and Arch packaging.

## Implementation milestones

### Milestone 1: core filtering and sorting engine
- Accept `/usr/share/dict/words` or user-configured wordlist paths.
- Support exact length filters, range filters, substring/regex matching, and wildcard patterns (`*`, `?`, `.`).
- Support rack-letter matching using letter-frequency accounting with a multiset tile pool constraint.
- Sort results by alphabetical order (`alpha`, `alpha_desc`), length, and Scrabble score.

### Milestone 2: native Omarchy plugin UX
- Provide a rich search overlay inside `omarchy-shell` with keyboard and mouse navigation.
- Support live updates for pattern, length, rack, and sort controls.
- Persist the last three searches across overlay sessions and restore them with `Ctrl+Up` / `Ctrl+Down`.
- Provide independent appearance controls for font family and UI scale (`75%–200%`).

### Milestone 3: dictionary lookup and definition flow
- Query local `dictd` for WordNet definitions and Moby Thesaurus synonyms in the overlay.
- Copy selected words to the clipboard with `wl-copy`.
- Show clear fallback messages when `dictd` or a database is unavailable.

### Milestone 4: self-contained plugin packaging
- Bundle the QML overlay, session module, translations, `search.py`, and Python engine modules directly in the `acme.lexicon` plugin directory.
- Package the app via `install.sh` and `PKGBUILD` as the Omarchy plugin without a standalone CLI binary.

## Progress checkpoints

- [x] Checkpoint 1 — Scaffold repository layout and core filtering engine.
- [x] Checkpoint 2 — Implement filtering engine (exact length, wildcard/regex, rack letters) with tests.
- [x] Checkpoint 3 — Validate the search engine and dictionary lookup flow.
- [x] Checkpoint 4 — Add dictionary lookup flow with graceful fallback when `dict` is unavailable.
- [x] Checkpoint 5 — Add config-driven defaults (`default.conf`).
- [x] Checkpoint 6 — Add Scrabble score sorting and min/max length filters.
- [x] Checkpoint 7 — Package the native Omarchy plugin (`acme.lexicon`) in `install.sh` and `PKGBUILD`.
- [x] Checkpoint 8 — Build the native Omarchy overlay with Words, Meaning, and Thesaurus columns and session history.
- [x] Checkpoint 9 — Configure optional local dictionary and thesaurus databases independently; verify lookups and fallbacks.
- [x] Checkpoint 10 — Acceptance testing of the search gateway and plugin installation.
- [x] Checkpoint 11 — Overlay arrows reach length, rack, sort; rack mode uses tile counts and clears length; font and `Ctrl +/-` size persist independently of saved searches; click routing and shell reload work reliably.
- [x] Checkpoint 12 — Package `omarchy-lexicon` purely as the self-contained Omarchy plugin app without a standalone CLI binary, and update all documentation.
