# Release notes

## v0.1.0 (first package publication)

`omarchy-lexicon` v0.1.0 ships a keyboard-first, offline word finder designed around the CLI engine and the requirement for a future native Omarchy plugin UX.

### Highlights

- Core word filtering by exact length, range, wildcard/substring/regex pattern, and rack letters.
- Result sorting by alphabetical order, word length, and Scrabble score.
- Optional local dictionary and thesaurus lookups through `dictd`.
- Clipboard copy support via `wl-copy`.
- Config defaults via `--config` and `/etc/omarchy-lexicon/default.conf`.
- Install helper script (`install.sh`) and Arch package scaffold (`PKGBUILD`).

### Validation summary

- Unit/integration test coverage includes filtering logic, CLI behavior, and install path checks.
- Manual UAT is documented in [UAT.md](./UAT.md), covering the supported CLI workflow and dictionary fallback behavior.

### Packaging notes

- Installed binary name: `/usr/bin/omarchy-lexicon`.
- Runtime Python modules install to: `/usr/lib/omarchy-lexicon/`.
- Default config path: `/etc/omarchy-lexicon/default.conf`.

### Known limitations

- Dictionary and thesaurus lookups require local `dictd` and installed databases.
- The current product is CLI-first; a native Omarchy plugin with richer UX remains the required next milestone.
