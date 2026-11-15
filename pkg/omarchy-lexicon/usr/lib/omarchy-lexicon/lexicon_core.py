from __future__ import annotations

import os
import re
from collections import Counter
from typing import Iterable, List, Sequence

DEFAULT_WORDLIST = "/usr/share/dict/words"


def normalize_word(word: str) -> str:
    cleaned = re.sub(r"[^A-Za-z]", "", word).lower()
    return cleaned


def wildcard_pattern_to_regex(pattern: str) -> re.Pattern[str]:
    escaped = re.escape(pattern)
    escaped = escaped.replace(r"\*", ".*")
    escaped = escaped.replace(r"\?", ".")
    escaped = escaped.replace(r"\.", ".")
    return re.compile(r"^" + escaped + r"$")


class WordFinder:
    def __init__(self, wordlist_path: str | None = None) -> None:
        self.wordlist_path = wordlist_path or os.environ.get("LEXICON_WORDLIST") or DEFAULT_WORDLIST

    def load_words(self, path: str | None = None) -> List[str]:
        target = path or self.wordlist_path
        if not target or not os.path.exists(target):
            raise FileNotFoundError(f"Word list not found: {target}")

        words: List[str] = []
        with open(target, "r", encoding="utf-8", errors="ignore") as handle:
            for line in handle:
                cleaned = normalize_word(line)
                if cleaned:
                    words.append(cleaned)
        return sorted(set(words))

    def filter_words(
        self,
        words: Sequence[str],
        *,
        length: int | None = None,
        pattern: str | None = None,
        rack: str | None = None,
    ) -> List[str]:
        filtered = list(words)

        if length is not None:
            filtered = [word for word in filtered if len(word) == length]

        if pattern:
            regex = wildcard_pattern_to_regex(pattern)
            filtered = [word for word in filtered if regex.fullmatch(word)]

        if rack:
            rack_counts = Counter(normalize_word(rack))
            filtered = [
                word
                for word in filtered
                if all(Counter(word).get(letter, 0) <= rack_counts.get(letter, 0) for letter in set(word))
            ]

        return filtered

    def sort_words(self, words: Iterable[str], mode: str = "alpha") -> List[str]:
        ordered = sorted(set(words))
        if mode == "length_asc":
            return sorted(ordered, key=lambda item: (len(item), item))
        if mode == "length_desc":
            return sorted(ordered, key=lambda item: (-len(item), item))
        return ordered

    def find_matches(
        self,
        *,
        length: int | None = None,
        pattern: str | None = None,
        rack: str | None = None,
        sort: str = "alpha",
        wordlist_path: str | None = None,
    ) -> List[str]:
        words = self.load_words(wordlist_path)
        filtered = self.filter_words(words, length=length, pattern=pattern, rack=rack)
        return self.sort_words(filtered, mode=sort)
