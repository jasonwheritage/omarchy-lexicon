from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from typing import Sequence

from dict_lookup import DictionaryLookup
from lexicon_core import DEFAULT_WORDLIST, WordFinder


def _read_wordlist_from_stdin() -> list[str]:
    words: list[str] = []
    for line in sys.stdin:
        text = line.strip()
        if text:
            words.append(text)
    return words


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Offline word finder for word games.")
    parser.add_argument("--wordlist", default=os.environ.get("LEXICON_WORDLIST", DEFAULT_WORDLIST), help="Path to a wordlist file")
    parser.add_argument("--length", type=int, help="Exact word length to match")
    parser.add_argument("--pattern", help="Wildcard or substring pattern, e.g. s.a.e or ing")
    parser.add_argument("--rack", help="Available rack letters, e.g. aeinrst")
    parser.add_argument("--sort", choices=["alpha", "length_asc", "length_desc"], default="alpha", help="Sorting mode")
    parser.add_argument("--limit", type=int, default=0, help="Maximum number of results to print")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of plain text")
    parser.add_argument("--copy", action="store_true", help="Copy the first result to wl-copy")
    parser.add_argument("--definition", action="store_true", help="Fetch the definition for the top result with dict")
    parser.add_argument("--from-stdin", action="store_true", help="Read words from standard input instead of a file")
    return parser


def _copy_to_clipboard(word: str) -> None:
    if shutil.which("wl-copy") is None:
        print("wl-copy is not installed; skipping clipboard copy.", file=sys.stderr)
        return

    subprocess.run(["wl-copy"], input=word.encode("utf-8"), check=False)


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    finder = WordFinder(args.wordlist)

    try:
        if args.from_stdin:
            words = _read_wordlist_from_stdin()
        else:
            words = finder.load_words(args.wordlist)
    except FileNotFoundError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    matches = finder.filter_words(
        words,
        length=args.length,
        pattern=args.pattern,
        rack=args.rack,
    )
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

    if matches and args.definition:
        result = DictionaryLookup().lookup(matches[0])
        print(f"\nDefinition for {matches[0]}:\n{result['definition']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
