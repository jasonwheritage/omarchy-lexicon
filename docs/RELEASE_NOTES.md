# Release notes

## v1.0.0

`omarchy-lexicon` v1.0.0 is the first public release of the native Omarchy word-finder and dictionary overlay plugin (`acme.lexicon`), ready for the Omarchy community marketplace (`omarchy plugin add`).

### Highlights

- Native `OverlayWindow` plugin (`acme.lexicon`) running inside `omarchy-shell` with full keyboard and mouse navigation.
- Live word filtering by wildcard (`*`, `?`, `.`), substring, and regular-expression patterns, exact word length (`1–32`), and multiset rack tile pools.
- Alphabetical (`A–Z` / `Z–A`) and letter-quantity (`Letters` shortest-first / longest-first) sorting.
- Three-column results view showing matching words, WordNet definitions, and Moby Thesaurus synonyms via local `dictd`.
- Persistent 3-search history ring (`Ctrl+Up` / `Ctrl+Down`, `Ctrl+Backspace` to reset).
- Independent appearance persistence with five font choices (`Theme`, `Sans`, `Serif`, `Mono`, `Writer`) and UI scaling (`75%–200%` via `−` / `+` buttons and `Ctrl +` / `Ctrl -`, `Ctrl+0` to reset).
- In-place pattern editing with an accent-colored blinking cursor and `Left` / `Right` caret navigation.
- Self-contained plugin packaging compatible with `omarchy plugin add`, `./install.sh`, and Arch `PKGBUILD`.

### Installation

- Omarchy plugin CLI: `omarchy plugin add https://github.com/jasonwheritage/omarchy-lexicon.git --enable`
- Local checkout installer: `./install.sh` (installs to `~/.config/omarchy/plugins/acme.lexicon/`)
- Arch package (`PKGBUILD`): `makepkg -si` (stages to `/usr/share/omarchy-lexicon/plugins/acme.lexicon/` and `/etc/omarchy-lexicon/default.conf`)
