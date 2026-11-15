# omarchy-lexicon

`omarchy-lexicon` is a keyboard-first offline word finder for word games. It filters a local dictionary by exact length, wildcard patterns, and rack-letter availability, then prints sorted results for use with `walker --dmenu` or other launcher workflows.

## Features

- Exact-length filtering (`--length 5`)
- Wildcard matching such as `s.a.e` and `ing` (`--pattern`)
- Anagram/rack filtering with letter frequency checks (`--rack aeinrst`)
- Result sorting (`--sort alpha`, `--sort length_asc`, `--sort length_desc`)
- Graceful offline dictionary lookup fallback using `dict`/`dictd` when available
- `wl-copy` clipboard support via `--copy`

## Quick start

```bash
./bin/omarchy-lexicon --wordlist /usr/share/dict/words --length 5 --sort alpha
./bin/omarchy-lexicon --pattern "s.a.e" --sort alpha
./bin/omarchy-lexicon --rack aeinrst --sort length_asc --limit 20
./bin/omarchy-lexicon --pattern "s.a.e" --copy --definition
```

## Repository layout

```text
omarchy-lexicon/
├── README.md
├── LICENSE
├── PKGBUILD
├── bin/
│   └── omarchy-lexicon
├── src/
│   ├── cli.py
│   ├── dict_lookup.py
│   ├── lexicon_core.py
│   ├── sorters.py
│   └── __init__.py
├── config/
│   └── default.conf
├── docs/
│   ├── INBOX.md
│   └── plan/
│       └── plan.md
├── tests/
│   ├── test_lexicon_core.py
│   └── test_dict_lookup.py
└── .gitignore
```

## How this milestone works

This repository is intentionally a minimal, CLI-first milestone for the project: it gives you a stable command-line entry point and a packaging scaffold that matches the Omarchy-first installation model without requiring a full QML plugin implementation yet.

### `bin/omarchy-lexicon`

The executable wrapper at [bin/omarchy-lexicon](bin/omarchy-lexicon) is deliberately tiny. It does three things:

1. Finds the repository root relative to the script location.
2. Adds the `src/` directory to `sys.path` so Python can import the project modules without an installation step.
3. Imports `main()` from `src/cli.py` and exits with its return code.

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
- default config: `/etc/omarchy-lexicon/default.conf`
- docs: `/usr/share/doc/omarchy-lexicon/README.md`

The package is intentionally simple:

```bash
makepkg -si
```

During a package build, Arch clones the upstream repository into `$srcdir`, then `package()` copies the relevant files from that working tree into the install root (`$pkgdir`). This allows the same repository to function both as a local dev checkout and as a package-ready source tree.

The current `PKGBUILD` is a stepping stone: it installs the working CLI, defines the expected paths, and keeps the package structure aligned with the future AUR/GitHub release path without committing to a full Quickshell plugin architecture yet.

## Planned Omarchy integration

The current implementation is a working CLI prototype for the repository's recommended first milestone and a launcher-friendly second milestone. The intended overlay flow is:

```bash
omarchy-lexicon --length 5 --sort alpha | walker --dmenu
```

This enables a fast, keyboard-first lookup loop similar to a launcher-driven word finder.
