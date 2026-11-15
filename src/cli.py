from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from typing import Sequence

from dict_lookup import DictionaryLookup
from lexicon_core import DEFAULT_WORDLIST, WordFinder
from lexicon_config import load_config

SORT_CHOICES = ("alpha", "length_asc", "length_desc", "score_desc", "score_asc")
PATTERN_MODE_CHOICES = ("auto", "wildcard", "substring", "regex")


def _read_wordlist_from_stdin() -> list[str]:
    words: list[str] = []
    for line in sys.stdin:
        text = line.strip()
        if text:
            words.append(text)
    return words


def _to_optional_int(value: str | None, *, source_key: str) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except ValueError as exc:
        raise ValueError(f"Invalid integer for {source_key}: {value}") from exc


def _resolve_defaults(argv: Sequence[str] | None) -> dict[str, str | int | None]:
    config_probe = argparse.ArgumentParser(add_help=False)
    config_probe.add_argument("--config", default=os.environ.get("LEXICON_CONFIG"))
    known_args, _ = config_probe.parse_known_args(argv)

    config = load_config(known_args.config)

    sort_mode = config.get("SORT_MODE", os.environ.get("LEXICON_SORT_MODE", "alpha"))
    if sort_mode not in SORT_CHOICES:
        raise ValueError(f"Invalid SORT_MODE: {sort_mode}")

    return {
        "wordlist": config.get("WORDLIST_PATH", os.environ.get("LEXICON_WORDLIST", DEFAULT_WORDLIST)),
        "length": _to_optional_int(config.get("DEFAULT_LENGTH"), source_key="DEFAULT_LENGTH"),
        "min_length": _to_optional_int(config.get("MIN_LENGTH"), source_key="MIN_LENGTH"),
        "max_length": _to_optional_int(config.get("MAX_LENGTH"), source_key="MAX_LENGTH"),
        "pattern": config.get("DEFAULT_PATTERN") or None,
        "pattern_mode": config.get("PATTERN_MODE", os.environ.get("LEXICON_PATTERN_MODE", "auto")),
        "rack": config.get("DEFAULT_RACK") or None,
        "dictionary": os.environ.get("LEXICON_DICTIONARY", config.get("DICTIONARY_DATABASE", "wn")),
        "thesaurus": os.environ.get("LEXICON_THESAURUS", config.get("THESAURUS_DATABASE", "moby-thesaurus")),
        "sort": sort_mode,
        "config_path": known_args.config,
    }


def build_parser(defaults: dict[str, str | int | None]) -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Offline word finder for word games.")
    parser.add_argument("--config", default=defaults["config_path"], help="Optional config file path")
    parser.add_argument("--wordlist", default=defaults["wordlist"], help="Path to a wordlist file")
    parser.add_argument("--length", type=int, default=defaults["length"], help="Exact word length to match")
    parser.add_argument("--min-length", type=int, default=defaults["min_length"], help="Minimum word length")
    parser.add_argument("--max-length", type=int, default=defaults["max_length"], help="Maximum word length")
    parser.add_argument("--pattern", default=defaults["pattern"], help="Wildcard or substring pattern, e.g. s.a.e or ing")
    parser.add_argument("--pattern-mode", choices=PATTERN_MODE_CHOICES, default=defaults["pattern_mode"], help="Pattern matching mode")
    parser.add_argument("--rack", default=defaults["rack"], help="Available rack letters, e.g. aeinrst")
    parser.add_argument("--sort", choices=SORT_CHOICES, default=defaults["sort"], help="Sorting mode")
    parser.add_argument("--limit", type=int, default=0, help="Maximum number of results to print")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of plain text")
    parser.add_argument("--copy", action="store_true", help="Copy the first result to wl-copy")
    parser.add_argument("--definition", action="store_true", help="Fetch the definition for the top result with dict")
    parser.add_argument("--synonyms", action="store_true", help="Fetch similar words from the thesaurus")
    parser.add_argument("--dictionary", default=defaults["dictionary"], help="Dictionary database name")
    parser.add_argument("--thesaurus", default=defaults["thesaurus"], help="Thesaurus database name")
    parser.add_argument("--lookup-word", help="Look up this word directly instead of searching a wordlist")
    parser.add_argument("--from-stdin", action="store_true", help="Read words from standard input instead of a file")
    return parser


def _copy_to_clipboard(word: str) -> None:
    if shutil.which("wl-copy") is None:
        print("wl-copy is not installed; skipping clipboard copy.", file=sys.stderr)
        return

    subprocess.run(["wl-copy"], input=word.encode("utf-8"), check=False)


def _show_lookups(args: argparse.Namespace, word: str) -> None:
    lookup = DictionaryLookup(database=args.dictionary, thesaurus=args.thesaurus)
    if args.definition:
        result = lookup.lookup(word)
        print(f"\nDefinition for {word}:\n{result['definition']}")
    if args.synonyms:
        result = lookup.similar(word)
        print(f"\nSimilar words for {word}:\n{result['definition']}")


def main(argv: Sequence[str] | None = None) -> int:
    try:
        defaults = _resolve_defaults(argv)
    except (FileNotFoundError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 2
    if defaults["pattern_mode"] not in PATTERN_MODE_CHOICES:
        print(f"Invalid PATTERN_MODE: {defaults['pattern_mode']}", file=sys.stderr)
        return 2

    parser = build_parser(defaults)
    args = parser.parse_args(argv)

    if args.min_length is not None and args.max_length is not None and args.min_length > args.max_length:
        print("--min-length cannot be greater than --max-length.", file=sys.stderr)
        return 2

    if args.lookup_word is not None:
        if not (args.definition or args.synonyms):
            parser.error("--lookup-word requires --definition or --synonyms")
        _show_lookups(args, args.lookup_word)
        return 0

    finder = WordFinder(args.wordlist)

    try:
        if args.from_stdin:
            words = _read_wordlist_from_stdin()
        else:
            words = finder.load_words(args.wordlist)
    except FileNotFoundError as exc:
        message = str(exc)
        if "Word list not found" in message:
            print(f"{message}", file=sys.stderr)
            print("Install the 'words' package: sudo pacman -S --needed words", file=sys.stderr)
        else:
            print(message, file=sys.stderr)
        return 1

    try:
        matches = finder.filter_words(
            words,
            length=args.length,
            min_length=args.min_length,
            max_length=args.max_length,
            pattern=args.pattern,
            pattern_mode=args.pattern_mode,
            rack=args.rack,
        )
    except re.error as exc:
        print(f"Invalid regular expression {args.pattern!r}: {exc}", file=sys.stderr)
        return 2
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    matches = finder.sort_words(matches, mode=args.sort)

    if args.limit and args.limit > 0:
        matches = matches[: args.limit]

    if args.json:
        print(json.dumps(matches, ensure_ascii=False))
    else:
        if not matches:
            print("No words matched the current filters.", file=sys.stderr)
        else:
            print("\n".join(matches))

    if matches and args.copy:
        _copy_to_clipboard(matches[0])

    if matches and (args.definition or args.synonyms):
        _show_lookups(args, matches[0])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
