# omarchy-lexicon project plan

## Recommended architecture

### Required path: native Omarchy plugin with rich UX

This project must move past the `walker` wrapper. The Walker path is not a real product surface because it is a selector, not a full search interface. The long-term requirement is a proper Omarchy plugin or Quickshell-backed app that provides rich search UX.

Why this is required:
- Users need a real interactive search form, not a filtered list selected from a terminal.
- Rack, regex, pattern, and dictionary results need a polished, immediate results surface.
- Omarchy users expect a native overlay or desktop plugin, not a shell script with dmenu behavior.
- The original product requirement is to give `omarchy-lexicon` a true Omarchy-native interaction model.

Proposed components:
- `bin/omarchy-lexicon` — CLI engine and validation entrypoint.
- `src/lexicon_core.py` and related modules — reusable filtering, scoring, and lookup logic.
- `config/default.conf` — config defaults for wordlist, dictionary, and plugin settings.
- `install.sh` and `PKGBUILD` — installation for the CLI and plugin assets.
- future native Omarchy plugin / Quickshell component — the required rich UX layer.

### Supporting path: CLI-first validation layer

The CLI remains valuable as a development and testing surface, and as a fallback for shell scripting or automation. It is not the end-user product UX.

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

### Milestone 2: native Omarchy plugin UX
- Build the first Omarchy plugin or shell integration that provides a proper rich search form.
- Support live input updates for regex, rack, length, and wildcard search without relying on `walker --dmenu`.
- Present matches in a native Omarchy results surface with clear selection and result metadata.
- Add a keybinding that launches the plugin in a desktop-native overlay or panel flow.

### Milestone 3: dictionary lookup and definition flow
- Keep definitions optional; use independently configured dictionary and thesaurus database names with local `dictd`.
- For Omarchy 4, recommend `sudo pacman -S dictd` and optionally `yay -S wordnet-dictd dict-gcide dict-moby-thesaurus`; other compatible databases remain supported.
- When a word is selected, copy it to the system clipboard using `wl-copy`.
- Attempt a local dictionary lookup and show the result in a follow-up notification or overlay.
- Fail gracefully if no dictionary service is installed, showing a clear message rather than blocking the workflow.

### Milestone 4: configuration and packaging
- Support custom wordlist paths via config or environment variables.
- Offer optional Scrabble scoring and toggles for word length preferences.
- Package the project using a `PKGBUILD` and distribution notes for installation under Omarchy.
- Ensure the binary naming follows the required convention: `/usr/bin/omarchy-lexicon`.
- For any plugin packaging path, ensure the manifest ID avoids the reserved `omarchy.` prefix.

## Progress checkpoints

Use these checkpoints to track implementation status during development:

- [x] Checkpoint 1 — Scaffold repository layout and CLI entrypoint.
- [x] Checkpoint 2 — Implement filtering engine (exact length, wildcard/regex, rack letters) with tests.
- [x] Checkpoint 3 — Validate the CLI engine and dictionary flow without a `walker` wrapper.
- [x] Checkpoint 4 — Add dictionary lookup flow with graceful fallback when `dict` is unavailable.
- [x] Checkpoint 5 — Add config-driven defaults (`--config` and `/etc/omarchy-lexicon/default.conf`).
- [x] Checkpoint 6 — Add Scrabble score sorting and min/max length preference toggles.
- [x] Checkpoint 7 — Package binaries and default config in `PKGBUILD`.
- [x] Checkpoint 8 — Document the product requirement to replace the fake launcher with a native Omarchy plugin.
- [x] Checkpoint 9 — Configure optional local dictionary and thesaurus databases independently; verify lookups and failures.
- [x] Checkpoint 10 — User acceptance testing of the CLI and documented product direction; reject the `walker` entry point as insufficient UX.

## Risk and compatibility notes
- Offline dictionary sources can vary by distro; the script should treat `/usr/share/dict/words` as the default but allow overrides.
- `dictd` and its databases may be unavailable or unconfigured; word searches must still work and lookup failures must be clear.
- The project should stay lightweight and keyboard-first, matching Omarchy’s philosophy rather than adding a heavyweight UI stack prematurely.

## Immediate next actions
1. [ ] Build the first native Omarchy plugin prototype with a proper search form and result surface.
2. [ ] Reuse the validated CLI engine as the plugin backend and keep the user-facing UX rich and Omarchy-native.
3. [ ] Publish the CLI package only as a support layer while the plugin remains the primary end-user product.

For the detailed lightweight architecture and plugin conventions, see [../ARCHITECTURE.md](../ARCHITECTURE.md).

This plan intentionally prioritizes a native Omarchy plugin as the required user experience; the CLI remains useful for testing, packaging, and automation, but not as the product’s final UX.
