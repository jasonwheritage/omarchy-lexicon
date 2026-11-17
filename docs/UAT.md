# User Acceptance Testing (UAT) Guide

This guide defines the repeatable acceptance test process for the `omarchy-lexicon` Omarchy overlay plugin (`acme.lexicon`) and its embedded search engine (`plugins/acme.lexicon/search.py`).

## 1) UAT scope

UAT confirms that an end user can:

- install and launch the `acme.lexicon` overlay in Omarchy
- filter words by exact length, wildcard/substring/regex patterns, and rack tile pool
- sort results alphabetically (`A–Z` / `Z–A`) and by quantity of letters (`Letters` shortest-first / longest-first)
- switch fonts and resize the overlay with `−` / `+` buttons and `Ctrl +` / `Ctrl -`
- view definitions and thesaurus entries when local `dictd` is running, with clear fallback messages when unavailable
- copy words to the Wayland clipboard

## 2) Prerequisites

- Omarchy desktop with Python 3, `words`, and `wl-clipboard`
- Optional for dictionary and thesaurus checks: `dictd` with `wordnet-dictd` and `dict-moby-thesaurus`

## 3) Deterministic test wordlist

```bash
cat > /tmp/uat-words.txt <<'EOF'
apple
grape
orange
pear
plum
stare
tares
tears
rates
quiz
EOF
```

## 4) Engine & gateway acceptance tests

### UAT-C01: Exact length filter
```bash
python3 ./plugins/acme.lexicon/search.py --wordlist /tmp/uat-words.txt --length 5 --sort alpha
```
- Expected JSON `results`: `["apple", "grape", "rates", "stare", "tares", "tears"]`

### UAT-C02: Rack tile-pool filter (including repeated tiles)
```bash
python3 ./plugins/acme.lexicon/search.py --wordlist /tmp/uat-words.txt --query ppale --rack ppale --sort alpha
```
- Expected JSON `results`: `["apple"]`

### UAT-C03: Substring pattern mode
```bash
python3 ./plugins/acme.lexicon/search.py --wordlist /tmp/uat-words.txt --query ang --pattern-mode substring
```
- Expected JSON `results`: `["orange"]`

### UAT-C04: Regex pattern mode
```bash
python3 ./plugins/acme.lexicon/search.py --wordlist /tmp/uat-words.txt --query '^t.*s$' --pattern-mode regex --sort alpha
```
- Expected JSON `results`: `["tares", "tears"]`

### UAT-C05: Descending sort
```bash
python3 ./plugins/acme.lexicon/search.py --wordlist /tmp/uat-words.txt --length 4 --sort alpha_desc
```
- Expected JSON `results`: `["quiz", "plum", "pear"]`

### UAT-H01: Invalid regex handling
```bash
python3 ./plugins/acme.lexicon/search.py --wordlist /tmp/uat-words.txt --query '(' --pattern-mode regex
```
- Expected: exit code `2` and JSON `"ok": false` with `"Invalid regular expression"` in `"error"`.

### UAT-H02: Invalid length range handling
```bash
python3 ./plugins/acme.lexicon/search.py --wordlist /tmp/uat-words.txt --min-length 7 --max-length 3
```
- Expected: exit code `2` and JSON `"ok": false` with `"--min-length cannot be greater than --max-length."` in `"error"`.

### UAT-H03: Config defaults load
```bash
cat > /tmp/uat.conf <<'EOF'
WORDLIST_PATH=/tmp/uat-words.txt
SORT_MODE=score_desc
DEFAULT_PATTERN=ang
PATTERN_MODE=substring
EOF
python3 ./plugins/acme.lexicon/search.py --config /tmp/uat.conf
```
- Expected JSON `results`: `["orange"]`

### UAT-M01: Self-contained plugin install
```bash
UAT_DIR="$(mktemp -d)"
PREFIX="$UAT_DIR/prefix" PLUGIN_TARGET_DIR="$UAT_DIR/plugin" HOME="$UAT_DIR" ./install.sh
python3 "$UAT_DIR/plugin/search.py" --wordlist /tmp/uat-words.txt --query app
```
- Expected: `$UAT_DIR/plugin` contains `manifest.json`, `LexiconOverlay.qml`, `session.js`, `search.py`, `lexicon_core.py`, and `i18n/en.json`, no `bin/omarchy-lexicon` binary is created, and the command outputs `"apple"`.

## 5) Interactive overlay verification

1. Run `./install.sh` and open the overlay with `omarchy-shell shell toggle acme.lexicon`.
2. Type `ppale`, click `Rack`, and confirm `Length` resets to `Any` and `apple` appears in the Words list.
3. Click `apple` in the Words list and confirm its definition and thesaurus entries load.
4. Click `Theme`, `Sans`, `Serif`, `Mono`, and `Writer` and confirm the overlay font updates immediately.
5. Click `−` and `+` (and press `Ctrl +` / `Ctrl -`) and confirm the overlay scales between `75%` and `200%`.
