#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Sequence

_HERE = Path(__file__).resolve().parent
for _candidate in (
    _HERE,
    _HERE.parent.parent / "src",
    Path("/usr/share/omarchy-lexicon/plugins/acme.lexicon"),
):
    if (_candidate / "lexicon_core.py").is_file() and str(_candidate) not in sys.path:
        sys.path.insert(0, str(_candidate))

from lexicon_config import load_config  # noqa: E402
from lexicon_core import DEFAULT_WORDLIST, WordFinder  # noqa: E402

_QUERY_FIELD = re.compile(r"^(len|length|min|max|rack)=(\S+)$", re.IGNORECASE)
SORT_CHOICES = ("alpha", "alpha_desc", "length_asc", "length_desc", "score_desc", "score_asc")
PATTERN_MODE_CHOICES = ("auto", "wildcard", "substring", "regex")


def _to_optional_int(value: str | int | None, *, source_key: str) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except ValueError as exc:
        raise ValueError(f"Invalid integer for {source_key}: {value}") from exc


def _interpret_query(query: str) -> dict[str, object]:
    pattern_parts: list[str] = []
    fields: dict[str, object] = {"pattern": ""}
    for token in (query or "").split():
        match = _QUERY_FIELD.match(token)
        if match is None:
            pattern_parts.append(token)
            continue
        key = match.group(1).lower()
        value = match.group(2)
        if key == "rack":
            if value.isalpha():
                fields["rack"] = value.lower()
            else:
                pattern_parts.append(token)
            continue
        if not value.isdigit():
            pattern_parts.append(token)
            continue
        number = int(value)
        if key in {"len", "length"}:
            fields["length"] = number
        elif key == "min":
            fields["min_length"] = number
        else:
            fields["max_length"] = number
    fields["pattern"] = " ".join(pattern_parts)
    return fields


def _apply_query_fields(args: argparse.Namespace) -> None:
    interpreted = _interpret_query(args.query)
    args.query = str(interpreted["pattern"])
    if args.length is None and "length" in interpreted:
        args.length = interpreted["length"]
    if args.min_length is None and "min_length" in interpreted:
        args.min_length = interpreted["min_length"]
    if args.max_length is None and "max_length" in interpreted:
        args.max_length = interpreted["max_length"]
    if not args.rack and interpreted.get("rack"):
        args.rack = str(interpreted["rack"])


def _letters(text: str) -> str:
    return re.sub(r"[^a-z]", "", (text or "").lower())


def _prefer_rack_pool(args: argparse.Namespace) -> None:
    """A rack is a multiset of tiles. Repeated letters represent repeated tiles."""
    if not args.rack:
        return
    rack = _letters(args.rack)
    args.rack = rack
    query = args.query or ""
    if query and _letters(query) == rack and re.fullmatch(r"[A-Za-z]+", query):
        args.query = ""


def _resolve_search_params(args: argparse.Namespace, config: dict[str, str] | None = None) -> dict[str, object]:
    cfg = config if config is not None else load_config(getattr(args, "config", None))
    _apply_query_fields(args)
    _prefer_rack_pool(args)

    sort_mode = args.sort or cfg.get("SORT_MODE") or os.environ.get("LEXICON_SORT_MODE") or "alpha"
    if sort_mode not in SORT_CHOICES:
        raise ValueError(f"Invalid SORT_MODE: {sort_mode}")

    pattern_mode = args.pattern_mode or cfg.get("PATTERN_MODE") or os.environ.get("LEXICON_PATTERN_MODE") or "auto"
    if pattern_mode not in PATTERN_MODE_CHOICES:
        raise ValueError(f"Invalid PATTERN_MODE: {pattern_mode}")

    length = args.length if args.length is not None else _to_optional_int(cfg.get("DEFAULT_LENGTH"), source_key="DEFAULT_LENGTH")
    min_length = args.min_length if args.min_length is not None else _to_optional_int(cfg.get("MIN_LENGTH"), source_key="MIN_LENGTH")
    max_length = args.max_length if args.max_length is not None else _to_optional_int(cfg.get("MAX_LENGTH"), source_key="MAX_LENGTH")
    if min_length is not None and max_length is not None and min_length > max_length:
        raise ValueError("--min-length cannot be greater than --max-length.")

    rack = args.rack or cfg.get("DEFAULT_RACK") or None
    pattern = args.query or (None if rack else cfg.get("DEFAULT_PATTERN") or None)
    wordlist = (
        getattr(args, "wordlist", None)
        or os.environ.get("LEXICON_WORDLIST")
        or os.environ.get("WORDLIST_PATH")
        or cfg.get("WORDLIST_PATH")
        or DEFAULT_WORDLIST
    )

    return {
        "wordlist_path": wordlist,
        "length": length,
        "min_length": min_length,
        "max_length": max_length,
        "pattern": pattern,
        "pattern_mode": pattern_mode,
        "rack": rack,
        "sort": sort_mode,
        "limit": args.limit,
    }


_THESAURUS_SKIP = {"and", "the", "for", "with", "from"}
_THESAURUS_WORD = re.compile(r"[A-Za-z][A-Za-z'-]*")


def parse_thesaurus_text(text: str, headword: str, limit: int = 200) -> list[str]:
    lines = text.splitlines()
    start = 0
    for index, line in enumerate(lines):
        if "words for" in line.lower():
            start = index + 1
            break
    body = " ".join(lines[start:])
    head = re.sub(r"[^a-z]", "", headword.lower())
    seen: set[str] = set()
    words: list[str] = []
    for match in _THESAURUS_WORD.finditer(body):
        word = match.group(0).lower().replace("'", "")
        if len(word) < 3 or word == head or word in _THESAURUS_SKIP or word in seen:
            continue
        seen.add(word)
        words.append(word)
        if len(words) >= limit:
            break
    return words


def lookup_definition(word: str, database: str = "wn") -> dict[str, object]:
    cleaned = re.sub(r"[^A-Za-z '-]", "", word).strip()[:80]
    if not cleaned:
        return {"ok": True, "word": "", "text": ""}
    if shutil.which("dict") is None:
        return {"ok": False, "error": "Dictionary unavailable", "text": ""}
    try:
        result = subprocess.run(
            ["dict", "-h", "localhost", "-d", database or "wn", "--", cleaned],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return {"ok": False, "error": "Dictionary unavailable", "text": ""}
    text = ((result.stdout or "") + "\n" + (result.stderr or "")).strip()
    if "cannot connect" in text.lower() or (result.returncode != 0 and not (result.stdout or "").strip()):
        return {"ok": False, "error": (text or "Dictionary unavailable")[:500], "text": ""}
    return {"ok": True, "word": cleaned, "text": text[:4000]}


def lookup_thesaurus(word: str, database: str = "moby-thesaurus") -> dict[str, object]:
    cleaned = re.sub(r"[^A-Za-z '-]", "", word).strip()[:80]
    if not cleaned:
        return {"ok": True, "word": "", "results": []}
    if shutil.which("dict") is None:
        return {"ok": False, "error": "Thesaurus unavailable", "results": []}
    try:
        result = subprocess.run(
            ["dict", "-h", "localhost", "-d", database or "moby-thesaurus", "--", cleaned],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return {"ok": False, "error": "Thesaurus unavailable", "results": []}
    text = ((result.stdout or "") + "\n" + (result.stderr or "")).strip()
    if "cannot connect" in text.lower():
        return {"ok": False, "error": "Thesaurus unavailable", "results": []}
    results = parse_thesaurus_text(text, cleaned)
    if result.returncode != 0 and not results and "no definitions" not in text.lower():
        return {"ok": False, "error": "Thesaurus unavailable", "results": []}
    return {"ok": True, "word": cleaned, "results": results}


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Omarchy plugin search engine for omarchy-lexicon")
    parser.add_argument("--config", default=os.environ.get("LEXICON_CONFIG"), help="Optional config file path")
    parser.add_argument("--wordlist", default=None, help="Optional wordlist file path")
    parser.add_argument("--query", default="", help="Query pattern to match, for example s.a.e or ing")
    parser.add_argument("--length", type=int, default=None, help="Exact word length")
    parser.add_argument("--min-length", type=int, default=None, help="Minimum word length")
    parser.add_argument("--max-length", type=int, default=None, help="Maximum word length")
    parser.add_argument("--rack", default="", help="Available rack letters")
    parser.add_argument("--pattern-mode", choices=PATTERN_MODE_CHOICES, default=None)
    parser.add_argument("--sort", choices=SORT_CHOICES, default=None)
    parser.add_argument("--limit", type=int, default=25, help="Maximum number of results to return")
    parser.add_argument("--thesaurus", default="", help="List similar words for this headword")
    parser.add_argument("--definition", default="", help="Look up a dictionary definition")
    parser.add_argument("--dictionary-db", default=None, help="Dictionary database name")
    parser.add_argument("--thesaurus-db", default=None, help="Thesaurus database name")
    args = parser.parse_args(argv)

    try:
        config = load_config(args.config)
    except (FileNotFoundError, ValueError) as exc:
        print(json.dumps({"ok": False, "error": str(exc), "results": []}, ensure_ascii=False))
        return 2

    dictionary_db = args.dictionary_db or os.environ.get("LEXICON_DICTIONARY") or config.get("DICTIONARY_DATABASE", "wn")
    thesaurus_db = args.thesaurus_db or os.environ.get("LEXICON_THESAURUS") or config.get("THESAURUS_DATABASE", "moby-thesaurus")

    if args.definition:
        payload = lookup_definition(args.definition, database=dictionary_db)
        print(json.dumps(payload, ensure_ascii=False))
        return 0 if payload.get("ok") else 1

    if args.thesaurus:
        payload = lookup_thesaurus(args.thesaurus, database=thesaurus_db)
        print(json.dumps(payload, ensure_ascii=False))
        return 0 if payload.get("ok") else 1

    try:
        params = _resolve_search_params(args, config)
        finder = WordFinder(str(params["wordlist_path"]))
        matches = finder.find_matches(
            length=params["length"],  # type: ignore[arg-type]
            min_length=params["min_length"],  # type: ignore[arg-type]
            max_length=params["max_length"],  # type: ignore[arg-type]
            pattern=params["pattern"],  # type: ignore[arg-type]
            pattern_mode=str(params["pattern_mode"]),
            rack=params["rack"],  # type: ignore[arg-type]
            sort=str(params["sort"]),
            wordlist_path=str(params["wordlist_path"]),
        )
    except re.error as exc:
        error = f"Invalid regular expression {args.query!r}: {exc}"
        print(json.dumps({"ok": False, "error": error, "results": []}, ensure_ascii=False))
        return 2
    except ValueError as exc:
        print(json.dumps({"ok": False, "error": str(exc), "results": []}, ensure_ascii=False))
        return 2
    except FileNotFoundError as exc:
        print(json.dumps({"ok": False, "error": str(exc), "results": []}, ensure_ascii=False))
        return 1

    limit = int(params["limit"]) if params["limit"] and int(params["limit"]) > 0 else len(matches)
    payload = {
        "ok": True,
        "query": args.query,
        "count": len(matches),
        "results": matches[:limit],
    }
    print(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
