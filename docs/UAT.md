# User Acceptance Testing (UAT) Guide

This guide defines a repeatable manual acceptance test process for `omarchy-lexicon`.

## 1) UAT scope

UAT confirms that an end user can:

- find words with length, rack, and pattern filters
- use pattern modes (auto, wildcard, substring, regex)
- sort results (alpha, length, score)
- use the CLI search flow directly
- copy selected words to clipboard
- request definitions and see graceful fallback when unavailable
- use config defaults and install-time package behavior

## 2) Prerequisites

- Linux desktop with Python 3
- Repository checked out locally
- Optional but recommended:
  - `wl-copy` / `wl-paste` (from `wl-clipboard`)
  - `dictd` and any locally configured dictionary and thesaurus databases for UAT-M04. See the [installation guidance](../README.md#wordlists-and-optional-dictionaries); the suggested Omarchy 4 packages are `wordnet-dictd`, `dict-gcide`, and `dict-moby-thesaurus`.

## 3) Test data setup

Create a deterministic word list for testing:

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

## 4) Execution procedure

1. Run each test case in Section 5 in order.
2. Record each result as Pass/Fail/Blocked in the table in Section 7.
3. For any failure, capture:
   - exact command used
   - observed output
   - expected output
   - environment notes (installed tools, distro/session type)
4. UAT passes only if all **Critical** and **High** tests pass.

## 5) Manual acceptance test suite

### Critical tests

#### UAT-C01: Exact length filter
- Command:
  ```bash
  ./bin/omarchy-lexicon --wordlist /tmp/uat-words.txt --length 5 --sort alpha
  ```
- Expected:
  - includes: `apple`, `grape`, `rates`, `stare`, `tares`, `tears`
  - excludes: `orange`, `pear`, `quiz`

#### UAT-C02: Rack filter
- Command:
  ```bash
  ./bin/omarchy-lexicon --wordlist /tmp/uat-words.txt --rack aerst --sort alpha
  ```
- Expected:
  - output is exactly: `rates`, `stare`, `tares`, `tears`

#### UAT-C03: Pattern mode substring
- Command:
  ```bash
  ./bin/omarchy-lexicon --wordlist /tmp/uat-words.txt --pattern ang --pattern-mode substring
  ```
- Expected:
  - output is exactly: `orange`

#### UAT-C04: Pattern mode regex
- Command:
  ```bash
  ./bin/omarchy-lexicon --wordlist /tmp/uat-words.txt --pattern '^t.*s$' --pattern-mode regex --sort alpha
  ```
- Expected:
  - output is exactly: `tares`, `tears`

#### UAT-C05: Score sort
- Command:
  ```bash
  ./bin/omarchy-lexicon --wordlist /tmp/uat-words.txt --sort score_desc --limit 3
  ```
- Expected:
  - first result is `quiz`

### High tests

#### UAT-H01: Invalid regex handling
- Command:
  ```bash
  ./bin/omarchy-lexicon --wordlist /tmp/uat-words.txt --pattern '(' --pattern-mode regex
  echo $?
  ```
- Expected:
  - non-zero exit code (2)
  - clear regex error message to stderr

#### UAT-H02: Invalid range handling
- Command:
  ```bash
  ./bin/omarchy-lexicon --wordlist /tmp/uat-words.txt --min-length 7 --max-length 3
  echo $?
  ```
- Expected:
  - non-zero exit code (2)
  - stderr says min length cannot exceed max length

#### UAT-H03: Config defaults load
- Setup:
  ```bash
  cat > /tmp/uat.conf <<'EOF'
  WORDLIST_PATH=/tmp/uat-words.txt
  SORT_MODE=score_desc
  DEFAULT_PATTERN=ang
  PATTERN_MODE=substring
  EOF
  ```
- Command:
  ```bash
  ./bin/omarchy-lexicon --config /tmp/uat.conf
  ```
- Expected:
  - output is exactly: `orange`

#### UAT-H04: Clipboard copy
- Command:
  ```bash
  ./bin/omarchy-lexicon --wordlist /tmp/uat-words.txt --pattern quiz --copy
  wl-paste
  ```
- Expected:
  - command prints `quiz`
  - clipboard content is `quiz` (if `wl-copy/wl-paste` available)

### Medium tests

#### UAT-M01: Missing dictionary fallback
- Run with `dict` hidden from the subprocess search path (no service configuration is changed):
  ```bash
  PATH=/nonexistent /usr/bin/python3 ./bin/omarchy-lexicon --wordlist /tmp/uat-words.txt --pattern apple --definition
  ```
- Expected: `apple` appears followed by a clear dictionary-unavailable message; the search completes.

#### UAT-M02: CLI lookup and clipboard flow
- Command:
  ```bash
  ./bin/omarchy-lexicon --wordlist /tmp/uat-words.txt --pattern quiz --copy
  wl-paste
  ```
- Expected:
  - the command prints `quiz`
  - the selected word is copied to clipboard (if `wl-copy` is available)
  - if `dict` is installed, a lookup can be run separately with `--definition` or `--synonyms`

#### UAT-M03: Install script
- Run in an isolated temporary prefix without changing desktop keybindings:
  ```bash
  UAT_PREFIX="$(mktemp -d)"
  PREFIX="$UAT_PREFIX" KEYBIND_TARGET_DIR="$UAT_PREFIX/no-keybinds" ./install.sh
  printf 'apple\n' | "$UAT_PREFIX/bin/omarchy-lexicon" --from-stdin
  ```
- Expected: binaries and config are installed under the temporary prefix, and the installed command prints `apple` without an import error.

#### UAT-M04: Configured dictionary and thesaurus
- With local `dictd` running, check installed database names:
  ```bash
  dict -h localhost -D
  ```
- Create a temporary config choosing one dictionary and one thesaurus; replace the names if using different databases:
  ```bash
  cat > /tmp/uat-dictionaries.conf <<'EOF'
  DICTIONARY_DATABASE=gcide
  THESAURUS_DATABASE=moby-thesaurus
  EOF
  ./bin/omarchy-lexicon --config /tmp/uat-dictionaries.conf --lookup-word happy --definition --synonyms
  ```
- Expected: a definition from GCIDE and similar words from Moby appear. The lookup does not require a wordlist. Record Blocked if the chosen databases are not installed or running.
- Optional override check: add `--dictionary wn` and confirm the definition is from WordNet instead. The thesaurus selection stays unchanged.

## 6) Acceptance criteria

Release candidate is acceptable when:

- All Critical tests pass
- All High tests pass
- No more than one Medium failure, and that failure has a documented workaround

## 7) UAT results

Latest results: 15 November 2026. Automated tests used a temporary wordlist and isolated install prefix; the local `dictd` served WordNet, GCIDE and Moby. **All 13 tests passed.**

| Test ID | Result | Notes |
|---|---|---|
| UAT-C01 | Pass | Exact-length results matched. |
| UAT-C02 | Pass | Rack results matched. |
| UAT-C03 | Pass | Substring returned `orange`. |
| UAT-C04 | Pass | Regex returned `tares` and `tears`. |
| UAT-C05 | Pass | `quiz` ranked first. |
| UAT-H01 | Pass | Invalid regex exits 2 and identifies the invalid regular expression. |
| UAT-H02 | Pass | Invalid range exited 2 with an explanatory error. |
| UAT-H03 | Pass | Configured defaults returned `orange`. |
| UAT-H04 | Pass | Clipboard copy confirmed by the user. |
| UAT-M01 | Pass | Missing `dict` produced the unavailable message without blocking the search. |
| UAT-M02 | Pass | CLI clipboard flow confirmed by the user. |
| UAT-M03 | Pass | Isolated installation and staged package CLI checks passed after the runtime-module fix. |
| UAT-M04 | Pass | GCIDE and Moby returned results; the WordNet override worked. |

**Resolved issues**

- UAT-M03 previously failed with `ModuleNotFoundError: No module named 'cli'`; runtime modules are now installed and exercised from outside the checkout.
- UAT-H01 now labels invalid regular expressions in response to earlier clarity feedback.

Earlier manual notes recorded C01–C04 as OK; their statuses were pending. A note under C05 reported the invalid-regex message, which concerns H01 rather than the score-sort test.
