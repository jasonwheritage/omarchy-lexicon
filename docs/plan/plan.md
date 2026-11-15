# omarchy-lexicon project plan

## Recommended architecture

### Path A: Bash/AWK + Walker dmenu + PKGBUILD (recommended first implementation)

Why this is the best starting point:
- Minimal moving parts and fastest time to a working launcher for Omarchy users.
- Uses the existing Omarchy workflow (`walker --dmenu`) without requiring a QML/Quickshell plugin build pipeline.
- Easy to package as an AUR/GitHub release with a standard Arch `PKGBUILD` and install script.
- Fits the user goal of a non-intrusive overlay workflow and supports keyboard-first word lookup.

Proposed components:
- `bin/omarchy-lexicon` — CLI entrypoint script.
- `lib/lexicon_filters.sh` or `scripts/lexicon.py` — pure filtering logic for exact length, regex/wildcards, and rack-letter matching.
- `config/default.conf` — optional user overrides for wordlist path, sorting mode, and keybinds.
- `install.sh` — installation helper that places the binary, config, and keybinding under Omarchy conventions.

### Path B: native Omarchy 4 shell plugin

Why it is attractive:
- Native Quickshell/Walker integration feels polished and can support richer overlay interactions.
- Better long-term UX if additional definitions, tray interactions, or plugin-specific configuration are required.

Trade-offs:
- More development overhead and a higher chance of packaging/validation friction.
- Requires Quickshell/QML knowledge and adds plugin-specific validation constraints (for example, the plugin ID must not use the reserved `omarchy.` prefix).
- Slower path to a working prototype compared with a Bash/AWK script.

Recommendation: ship Path A as the first milestone, then evolve toward a native plugin only if the UX needs exceed the script-based overlay.

## Repository structure

```text
omarchy-lexicon/
├── README.md
├── LICENSE
├── PKGBUILD
├── install.sh
├── bin/
│   └── omarchy-lexicon
├── src/
│   ├── lexicon_core.py
│   ├── filters.py
│   ├── sorters.py
│   └── dict_lookup.py
├── config/
│   └── default.conf
├── docs/
│   ├── plan/
│   │   └── plan.md
│   └── INBOX.md
└── tests/
    ├── test_filters.py
    ├── test_sorters.py
    └── test_dict_lookup.py
```

## Implementation milestones

### Milestone 1: core filtering and sorting engine
- Accept a wordlist source: `/usr/share/dict/words` or user-configured paths.
- Support exact length filters, substring/regex matching, and wildcard patterns such as `s.a.e`.
- Support rack-letter matching using letter-frequency accounting with a strict pool constraint.
- Sort results by alphabetical order and by length (ascending and descending).
- Keep processing efficient enough for large dictionary files; avoid repeated full-file reads and prefer streaming or indexed filtering where reasonable.

### Milestone 2: launcher/overlay UX
- Expose a CLI menu using `walker --dmenu` for live fuzzy filtering against the generated results.
- Accept fast queries and update the filtered list as the user types.
- Provide a simple output format that is easy to pipe into a selection flow and clipboard copy command.
- Add a keybinding (`SUPER SHIFT, D` is a sensible default) to launch the word finder without disrupting the workflow.

### Milestone 3: dictionary lookup and definition flow
- Check whether `dictd` and `dict-wn` are installed and available on the system.
- When a word is selected, copy it to the system clipboard using `wl-copy`.
- Attempt a local dictionary lookup and show the result in a follow-up notification or overlay.
- Fail gracefully if no dictionary service is installed, showing a clear message rather than blocking the workflow.

### Milestone 4: configuration and packaging
- Support custom wordlist paths via config or environment variables.
- Offer optional Scrabble scoring and toggles for word length preferences.
- Package the project using a `PKGBUILD` and distribution notes for installation under Omarchy.
- Ensure the binary naming follows the required convention: `/usr/bin/omarchy-lexicon`.
- For any plugin packaging path, ensure the manifest ID avoids the reserved `omarchy.` prefix.

## Risk and compatibility notes
- Offline dictionary sources can vary by distro; the script should treat `/usr/share/dict/words` as the default but allow overrides.
- `dictd`/`dict-wn` availability may be inconsistent on minimal installations; fallback messaging is required.
- The project should stay lightweight and keyboard-first, matching Omarchy’s philosophy rather than adding a heavyweight UI stack prematurely.

## Immediate next actions
1. Scaffold the repository layout and a minimal CLI entrypoint.
2. Implement the word filtering engine and test it against a sample dictionary.
3. Wire the launcher overlay to `walker --dmenu` and verify the live selection flow.
4. Add packaging metadata and install instructions for AUR/GitHub release usage.

This plan intentionally prioritizes a working, releaseable prototype with a clear upgrade path to a native Omarchy plugin if product feedback justifies it.
