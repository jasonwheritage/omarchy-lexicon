# Release notes

## v0.1.0 (first package publication)

`omarchy-lexicon` v0.1.0 ships a keyboard-first, offline word finder designed for Omarchy launcher workflows.

### Highlights

- Core word filtering by exact length, range, wildcard/substring/regex pattern, and rack letters.
- Result sorting by alphabetical order, word length, and Scrabble score.
- Optional local dictionary and thesaurus lookups through `dictd`.
- Walker launcher integration through `bin/omarchy-lexicon-walker`.
- Clipboard copy support via `wl-copy`.
- Config defaults via `--config` and `/etc/omarchy-lexicon/default.conf`.
- Install helper script (`install.sh`) and Arch package scaffold (`PKGBUILD`).

### Validation summary

- Unit/integration test coverage includes filtering logic, CLI behavior, install path checks, and walker wrapper behavior.
- Manual UAT is documented in [UAT.md](./UAT.md), with all 13 acceptance tests passing on 15 November 2026.

### Packaging notes

- Installed binary name: `/usr/bin/omarchy-lexicon`.
- Companion launcher wrapper: `/usr/bin/omarchy-lexicon-walker`.
- Runtime Python modules install to: `/usr/lib/omarchy-lexicon/`.
- Default config path: `/etc/omarchy-lexicon/default.conf`.
- Default Hyprland keybind snippet: `bind = SUPER SHIFT, D, exec, omarchy-lexicon-walker`.

### Known limitations

- Dictionary and thesaurus lookups require local `dictd` and installed databases.
- If `walker` or `wl-copy` are unavailable, related launcher/clipboard behavior is limited to available tools.
- Native Omarchy shell plugin work is intentionally deferred pending user demand for richer overlay UX.
