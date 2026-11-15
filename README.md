# omarchy-lexicon

`omarchy-lexicon` is a keyboard-first offline word finder for word games. It filters a local dictionary by exact length, wildcard patterns, and rack-letter availability, then prints sorted results for use with `walker --dmenu` or other launcher workflows.

## Features

- Exact-length filtering (`--length 5`)
- Length range filtering (`--min-length 4 --max-length 7`)
- Pattern matching with wildcard, substring, or regex modes (`--pattern`, `--pattern-mode`)
- Anagram/rack filtering with letter frequency checks (`--rack aeinrst`)
- Result sorting (`--sort alpha`, `--sort length_asc`, `--sort length_desc`, `--sort score_desc`, `--sort score_asc`)
- Optional offline definitions and similar words via a local `dictd` server
- `wl-copy` clipboard support via `--copy`
- Config-file defaults via `--config` or `/etc/omarchy-lexicon/default.conf`

## Quick start

```bash
./bin/omarchy-lexicon --wordlist /usr/share/dict/words --length 5 --sort alpha
./bin/omarchy-lexicon --pattern "s.a.e" --sort alpha
./bin/omarchy-lexicon --pattern "ing" --pattern-mode substring
./bin/omarchy-lexicon --pattern "^t.*s$" --pattern-mode regex
./bin/omarchy-lexicon --rack aeinrst --sort length_asc --limit 20
./bin/omarchy-lexicon --min-length 4 --max-length 8 --sort score_desc --limit 25
./bin/omarchy-lexicon --pattern "s.a.e" --copy --definition
./bin/omarchy-lexicon --config ./config/default.conf
```

## Wordlists and optional dictionaries

Word searches use `/usr/share/dict/words` by default, independently of `dictd`. If it is missing, supply a local wordlist with `--wordlist` or `WORDLIST_PATH` in the config file.

For optional offline definitions and similar words on Omarchy 4, one recommended setup is:

```bash
sudo pacman -S --needed dictd
yay -S wordnet-dictd dict-gcide dict-moby-thesaurus
```

The three dictionary packages are AUR packages; review their build instructions before installing. They are recommendations, not requirements: other databases served by local `dictd` work too. Start or restart `dictd` after installing databases and verify them:

```bash
sudo systemctl enable --now dictd
sudo systemctl restart dictd
dict -h localhost -D
```

A `dictd.conf` parse error can mean no database is configured; see the [ArchWiki dictd guide](https://wiki.archlinux.org/title/Dictd). WordNet (`wn`) and Moby (`moby-thesaurus`) are the default definition and thesaurus databases. Choose one of each using `DICTIONARY_DATABASE` and `THESAURUS_DATABASE` in the config file, environment variables `LEXICON_DICTIONARY` and `LEXICON_THESAURUS`, or CLI options `--dictionary` and `--thesaurus` (CLI overrides environment, which overrides config).

```bash
./bin/omarchy-lexicon --lookup-word apple --definition --dictionary gcide
./bin/omarchy-lexicon --lookup-word happy --synonyms --thesaurus moby-thesaurus
```

The Walker wrapper looks up the selected word's definition when `dict` is installed; set `LEXICON_SYNONYMS=1` to also show similar words in its output. Dictionary failures do not stop word searches.

## Repository layout

```text
omarchy-lexicon/
├── README.md
├── LICENSE
├── PKGBUILD
├── install.sh
├── bin/
│   ├── omarchy-lexicon
│   └── omarchy-lexicon-walker
├── src/
│   ├── cli.py
│   ├── dict_lookup.py
│   ├── lexicon_config.py
│   ├── lexicon_core.py
│   ├── sorters.py
│   └── __init__.py
├── config/
│   ├── default.conf
│   └── keybinds.conf
├── docs/
│   ├── INBOX.md
│   └── plan/
│       └── plan.md
├── tests/
│   ├── test_cli.py
│   ├── test_lexicon_core.py
│   └── test_dict_lookup.py
└── .gitignore
```

## How this milestone works

This repository is intentionally a minimal, CLI-first milestone for the project: it gives you a stable command-line entry point and a packaging scaffold that matches the Omarchy-first installation model without requiring a full QML plugin implementation yet.

### `bin/omarchy-lexicon`

The executable wrapper at [bin/omarchy-lexicon](bin/omarchy-lexicon) is deliberately tiny. It does three things:

1. Finds the project root or installation prefix relative to the script location.
2. Adds the checkout's `src/` or the installed `lib/omarchy-lexicon/` directory to `sys.path`.
3. Imports `main()` from `cli.py` and exits with its return code.

That means the project can be run directly from a checkout while still exposing a clean, installable binary name for packaging.

Example flow:

```bash
./bin/omarchy-lexicon --length 5 --sort alpha
./bin/omarchy-lexicon --pattern "s.a.e" --sort alpha
```

This wrapper is the bridge between the repository layout and the eventual installed binary path (`/usr/bin/omarchy-lexicon`).

### `bin/omarchy-lexicon-walker`

The second milestone adds a launcher wrapper at [bin/omarchy-lexicon-walker](bin/omarchy-lexicon-walker). It is designed to fit the intended Omarchy workflow:

```bash
./bin/omarchy-lexicon-walker
```

The script:

- Builds the matching arguments for the underlying CLI.
- Generates the filtered word list using the repository's dictionary logic.
- Passes that list to `walker --dmenu` for live keyboard selection.
- Copies the selected result to the clipboard with `wl-copy`.
- Optionally prints a local dictionary definition if `dict` is available.

This is the first real bridge from the text-mode engine to the in-application launcher UX that Omarchy users expect.

### `PKGBUILD`

The Arch package file in [PKGBUILD](PKGBUILD) is a first-pass packaging milestone. It is designed to install the runtime files into the system paths an Omarchy user expects:

- binary: `/usr/bin/omarchy-lexicon`
- Python modules: `/usr/lib/omarchy-lexicon/`
- default config: `/etc/omarchy-lexicon/default.conf`
- docs: `/usr/share/doc/omarchy-lexicon/README.md`

The package is intentionally simple:

```bash
makepkg -si
```

During a package build, Arch clones the upstream repository into `$srcdir`, then `package()` copies the relevant files from that working tree into the install root (`$pkgdir`). This allows the same repository to function both as a local dev checkout and as a package-ready source tree.

The current `PKGBUILD` is a stepping stone: it installs the working CLI, defines the expected paths, and keeps the package structure aligned with the future AUR/GitHub release path without committing to a full Quickshell plugin architecture yet.

### Configuration defaults

You can provide defaults in `/etc/omarchy-lexicon/default.conf` (or pass another file with `--config` or `LEXICON_CONFIG`). For an `install.sh` installation, the default is `$PREFIX/etc/omarchy-lexicon/default.conf` when present, with `/etc/omarchy-lexicon/default.conf` as a fallback:

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

### Keybinding

The default keybinding snippet is in `config/keybinds.conf`:

```ini
bind = SUPER SHIFT, D, exec, omarchy-lexicon-walker
```

Running `./install.sh` installs this snippet into `~/.config/hypr/conf.d/omarchy-lexicon.conf` when that folder exists.

## Planned Omarchy integration

The current implementation is a working CLI prototype for the repository's recommended first milestone and a launcher-friendly second milestone. The intended overlay flow is:

```bash
omarchy-lexicon --length 5 --sort alpha | walker --dmenu
```

This enables a fast, keyboard-first lookup loop similar to a launcher-driven word finder.

## User acceptance testing

For manual release validation and recorded results, follow the UAT procedure in [docs/UAT.md](./docs/UAT.md).
