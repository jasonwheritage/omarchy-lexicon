# Release notes

## v1.1.1

A safety release: Lexicon no longer changes your configuration without your say-so.

### Fixes

- Arch package upgrades keep your edited `/etc/omarchy-lexicon/default.conf`; pacman saves the new default as `default.conf.pacnew`.
- `./uninstall.sh` keeps your configuration and saved searches. Use `./uninstall.sh --purge` to delete them too.
- Adding and removing the `acme.lexicon` entry in `~/.config/omarchy/shell.json` now keeps the rest of the file and its formatting, writes safely so an interrupted install can't break it, works with symlinked dotfiles, and leaves the file untouched (with a warning) if it can't be read safely.
- `~/.config/omarchy-lexicon/default.conf` always takes priority. The release download now includes the config only as `default.conf.example`, so it can't override your settings.

## v1.1.0

A redesign of the overlay into a split view, with friendlier dictionary lookups and clearer setup instructions.

### Highlights

- New split-view layout: a word list with letter counts on the left, and a detail card with `Meaning` and `Synonyms` tabs on the right.
- A much clearer selected word (accent bar, border and bold text), and grouped controls where the active option is filled with the accent colour: `Any | − | N letters | +`, `Pattern | Rack`, `A–Z | Length`, and a sort direction chip.
- Font and size settings moved to a quiet footer, with keyboard hints alongside. Clicking the size percentage resets it.
- Synonyms are clickable chips; clicking one opens its meaning.
- Words without a dictionary entry fall back to the closest one (for example `flamethrowers` → `flamethrower`), with a "Showing the closest entry" note. Unknown words show "No dictionary entry" instead of raw `dict` output, and the synonym list no longer picks up words from that message.
- Definitions no longer repeat `dict`'s banner lines or the headword.
- `←` / `→` switch between the `Meaning` and `Synonyms` tabs; `Ctrl+C` on `Meaning` copies the word shown there. All other shortcuts are unchanged.
- README: a three-point summary, a screenshot, and a short explained step for installing the word list and dictionaries. The `PKGBUILD` lists the dictionary packages as optional dependencies.

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
