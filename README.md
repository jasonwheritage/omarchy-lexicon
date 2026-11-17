# omarchy-lexicon

`omarchy-lexicon` is a keyboard-first, offline word finder and dictionary overlay plugin for Omarchy (`acme.lexicon`). It runs inside the existing `omarchy-shell` process and filters a local wordlist by pattern, exact length, and rack-letter pool while displaying WordNet definitions and Moby Thesaurus synonyms side by side.

## Features

- Native Omarchy `OverlayWindow` plugin (`acme.lexicon`) with live search as you type
- Wildcard (`*`, `?`, `.`), substring, and regular-expression pattern matching
- Exact word-length filter (`0` for any length, `1–32` for exact length)
- Rack tile-pool mode: matches words that can be formed from the supplied letters, honoring repeated letters up to their tile count and automatically clearing the length filter when enabled
- Alphabetical (`A–Z` / `Z–A`) and letter-quantity (`Letters` shortest-first / longest-first) sorting
- Three-column results view: matching words, definition (`dictd` WordNet), and thesaurus (`dictd` Moby Thesaurus)
- Persistent session ring (last three searches with `Ctrl+Up` / `Ctrl+Down` and `Ctrl+Backspace` to reset)
- Independent appearance settings: five in-app font options (`Theme`, `Sans`, `Serif`, `Mono`, `Writer`) and UI scaling (`75%–200%` via `−` / `+` buttons or `Ctrl +` / `Ctrl -`, `Ctrl+0` to reset)
- `wl-copy` clipboard integration (`Enter` copies the focused word and closes; `Ctrl+C` copies while staying open)

## Installation

### Prerequisites

The default wordlist is `/usr/share/dict/words`. Install the Arch `words` package if it is missing:

```bash
sudo pacman -S --needed words
```

### Install with Omarchy's plugin manager (Recommended)

```bash
omarchy plugin add https://github.com/jasonwheritage/omarchy-lexicon.git --enable
```

### Install from a local checkout

```bash
git clone https://github.com/jasonwheritage/omarchy-lexicon.git
cd omarchy-lexicon
./install.sh
```

`./install.sh` installs the self-contained plugin and its Python search engine modules into `~/.config/omarchy/plugins/acme.lexicon`, writes default configuration to `~/.local/etc/omarchy-lexicon/default.conf` (when absent), registers `acme.lexicon` in `~/.config/omarchy/shell.json`, and restarts `omarchy-shell` so the overlay is immediately available.

### Build and install with `PKGBUILD` (Arch)

```bash
makepkg -si
```

This packages the plugin tree under `/usr/share/omarchy-lexicon/plugins/acme.lexicon` and installs `/etc/omarchy-lexicon/default.conf` and `/usr/share/doc/omarchy-lexicon/README.md`.

### Uninstall

```bash
./uninstall.sh
```

## Launching the overlay

Toggle the overlay from the shell command or bind it in `~/.config/hypr/bindings.lua`:

```bash
omarchy-shell shell toggle acme.lexicon
```

Example Hyprland binding in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + D", "Lexicon", { panel = "acme.lexicon" })
```

## Overlay controls

| Control | Keyboard | Mouse |
|---|---|---|
| Search pattern | Type directly in the search box (`*` any, `?` or `.` single letter) | Click the search box; text selection is supported |
| Length filter | Arrow to `Length`, then type digits (`0–9`), `Backspace`, or `+` / `-` | Click `Length` to focus |
| Rack mode | Arrow to `Rack` and press `Space` | Click the `Rack` chip |
| Sort by letter count | Arrow to `Letters` and press `Space` | Click the `Letters` chip |
| Sort order | Arrow to `Ascending` / `Descending` and press `Space` (or `Ctrl+Left` / `Ctrl+Right`) | Click the `Ascending` / `Descending` chip |
| Scale (`75%–200%`) | `Ctrl +` / `Ctrl =` to enlarge, `Ctrl -` to shrink, `Ctrl+0` to reset | Click `−` or `+` |
| Font family | Persisted independently of search history | Click `Theme`, `Sans`, `Serif`, `Mono`, or `Writer` |
| Words / Meaning / Thesaurus | Arrow keys or `Tab` / `Shift+Tab` between zones | Click any word or synonym to inspect its definition |
| Copy & dismiss | `Enter` copies focused word and closes; `Ctrl+C` copies; `Escape` closes | Click outside the card to close |

## Optional offline dictionaries (`dictd`)

Word filtering works from `/usr/share/dict/words` alone. For definitions and synonyms in the overlay, install and enable `dictd` with local databases:

```bash
sudo pacman -S --needed dictd
yay -S wordnet-dictd dict-gcide dict-moby-thesaurus
sudo systemctl enable --now dictd
sudo systemctl restart dictd
dict -h localhost -D
```

WordNet (`wn`) and Moby (`moby-thesaurus`) are the default databases. You can customize them in `/etc/omarchy-lexicon/default.conf` or `~/.config/omarchy-lexicon/default.conf`:

```ini
WORDLIST_PATH=/usr/share/dict/words
SORT_MODE=alpha
DEFAULT_LENGTH=
MIN_LENGTH=
MAX_LENGTH=
DEFAULT_PATTERN=
PATTERN_MODE=auto
DEFAULT_RACK=
DICTIONARY_DATABASE=wn
THESAURUS_DATABASE=moby-thesaurus
```

## Repository layout

```text
omarchy-lexicon/
├── README.md
├── LICENSE
├── PKGBUILD
├── install.sh
├── uninstall.sh
├── config/
│   └── default.conf
├── plugins/
│   └── acme.lexicon/
│       ├── manifest.json
│       ├── LexiconOverlay.qml
│       ├── session.js
│       ├── search.py
│       └── i18n/
│           └── en.json
├── src/
│   ├── dict_lookup.py
│   ├── lexicon_config.py
│   ├── lexicon_core.py
│   ├── sorters.py
│   └── __init__.py
├── docs/
│   ├── ARCHITECTURE.md
│   ├── INBOX.md
│   ├── RELEASE_NOTES.md
│   ├── UAT.md
│   └── plan/
│       └── plan.md
└── tests/
    ├── test_dict_lookup.py
    ├── test_installation.py
    ├── test_lexicon_core.py
    ├── test_search_gateway.py
    └── test_session.py
```

## Testing

Run the automated test suite from the repository root:

```bash
python3 -m unittest discover -s tests
```

See [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) for the plugin architecture and [docs/UAT.md](./docs/UAT.md) for acceptance testing.
