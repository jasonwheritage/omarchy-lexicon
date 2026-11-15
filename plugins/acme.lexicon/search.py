#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def _resolve_backend() -> str:
    candidates = [
        Path(__file__).resolve().parents[2] / "bin" / "omarchy-lexicon",
        Path("/usr/local/bin/omarchy-lexicon"),
        Path("/usr/bin/omarchy-lexicon"),
    ]
    for candidate in candidates:
        if candidate.exists() and candidate.is_file():
            return str(candidate)
    raise FileNotFoundError("omarchy-lexicon backend not found; install it or run the repo checkout")


def _build_command(args: argparse.Namespace) -> list[str]:
    backend = _resolve_backend()
    command = [backend, "--json", "--sort", args.sort, "--limit", str(args.limit)]

    if args.query:
        command.extend(["--pattern", args.query])
    if args.length is not None:
        command.extend(["--length", str(args.length)])
    if args.min_length is not None:
        command.extend(["--min-length", str(args.min_length)])
    if args.max_length is not None:
        command.extend(["--max-length", str(args.max_length)])
    if args.rack:
        command.extend(["--rack", args.rack])
    if args.pattern_mode:
        command.extend(["--pattern-mode", args.pattern_mode])

    wordlist = os.environ.get("LEXICON_WORDLIST") or os.environ.get("WORDLIST_PATH")
    if wordlist:
        command.extend(["--wordlist", wordlist])

    return command


def main() -> int:
    parser = argparse.ArgumentParser(description="Omarchy plugin search gateway for omarchy-lexicon")
    parser.add_argument("--query", default="", help="Query pattern to match, for example s.a.e or ing")
    parser.add_argument("--length", type=int, default=None, help="Exact word length")
    parser.add_argument("--min-length", type=int, default=None, help="Minimum word length")
    parser.add_argument("--max-length", type=int, default=None, help="Maximum word length")
    parser.add_argument("--rack", default="", help="Available rack letters")
    parser.add_argument("--pattern-mode", choices=("auto", "wildcard", "substring", "regex"), default="auto")
    parser.add_argument("--sort", choices=("alpha", "length_asc", "length_desc", "score_desc", "score_asc"), default="alpha")
    parser.add_argument("--limit", type=int, default=25, help="Maximum number of results to return")
    args = parser.parse_args()

    try:
        command = _build_command(args)
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        stdout = result.stdout.strip()
        if result.returncode != 0:
            payload = {"ok": False, "error": (result.stderr or stdout).strip() or "search failed", "results": []}
            print(json.dumps(payload, ensure_ascii=False))
            return 1

        try:
            matches = json.loads(stdout) if stdout else []
        except json.JSONDecodeError as exc:
            payload = {"ok": False, "error": f"invalid backend JSON: {exc}", "results": []}
            print(json.dumps(payload, ensure_ascii=False))
            return 1

        payload = {
            "ok": True,
            "query": args.query,
            "count": len(matches),
            "results": matches[: args.limit],
        }
        print(json.dumps(payload, ensure_ascii=False))
        return 0
    except FileNotFoundError as exc:
        print(json.dumps({"ok": False, "error": str(exc), "results": []}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
