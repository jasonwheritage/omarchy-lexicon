from __future__ import annotations

import os
import re
from collections import Counter
from typing import Iterable, List, Sequence

DEFAULT_WORDLIST_CANDIDATES = (
    "/usr/share/dict/words",
    "/usr/share/dict/words.txt",
    "/usr/share/dict/cracklib-small",
    "/usr/share/cracklib/cracklib-small",
)
DEFAULT_WORDLIST = next((path for path in DEFAULT_WORDLIST_CANDIDATES if os.path.exists(path)), "/usr/share/dict/words")
SCRABBLE_SCORES: dict[str, int] = {
    "a": 1,
    "b": 3,
    "c": 3,
    "d": 2,
    "e": 1,
    "f": 4,
    "g": 2,
    "h": 4,
    "i": 1,
    "j": 8,
    "k": 5,
    "l": 1,
    "m": 3,
    "n": 1,
    "o": 1,
    "p": 3,
    "q": 10,
    "r": 1,
    "s": 1,
    "t": 1,
    "u": 1,
    "v": 4,
    "w": 4,
    "x": 8,
    "y": 4,
    "z": 10,
}


def normalize_word(word: str) -> str:
    cleaned = re.sub(r"[^A-Za-z]", "", word).lower()
    return cleaned


def wildcard_pattern_to_regex(pattern: str) -> re.Pattern[str]:
    escaped = re.escape(pattern)
    escaped = escaped.replace(r"\*", ".*")
    escaped = escaped.replace(r"\?", ".")
    escaped = escaped.replace(r"\.", ".")
    return re.compile(r"^" + escaped + r"$")


def score_word(word: str) -> int:
    return sum(SCRABBLE_SCORES.get(letter, 0) for letter in word)


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
        min_length: int | None = None,
        max_length: int | None = None,
        pattern: str | None = None,
        pattern_mode: str = "auto",
        rack: str | None = None,
    ) -> List[str]:
        filtered = list(words)

        if length is not None:
            filtered = [word for word in filtered if len(word) == length]
        if min_length is not None:
            filtered = [word for word in filtered if len(word) >= min_length]
        if max_length is not None:
            filtered = [word for word in filtered if len(word) <= max_length]

        if pattern:
            normalized_pattern = pattern.lower()
            resolved_mode = pattern_mode
            if pattern_mode == "auto":
                resolved_mode = "wildcard" if any(token in pattern for token in (".", "*", "?")) else "substring"

            if resolved_mode == "substring":
                filtered = [word for word in filtered if normalized_pattern in word]
            elif resolved_mode == "wildcard":
                regex = wildcard_pattern_to_regex(normalized_pattern)
                filtered = [word for word in filtered if regex.fullmatch(word)]
            elif resolved_mode == "regex":
                regex = re.compile(pattern, re.IGNORECASE)
                filtered = [word for word in filtered if regex.search(word)]
            else:
                raise ValueError(f"Invalid pattern mode: {pattern_mode}")

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
        if mode == "score_desc":
            return sorted(ordered, key=lambda item: (-score_word(item), item))
        if mode == "score_asc":
            return sorted(ordered, key=lambda item: (score_word(item), item))
        if mode == "alpha_desc":
            return list(reversed(ordered))
        return ordered

    def find_matches(
        self,
        *,
        length: int | None = None,
        min_length: int | None = None,
        max_length: int | None = None,
        pattern: str | None = None,
        pattern_mode: str = "auto",
        rack: str | None = None,
        sort: str = "alpha",
        wordlist_path: str | None = None,
    ) -> List[str]:
        words = self.load_words(wordlist_path)
        filtered = self.filter_words(
            words,
            length=length,
            min_length=min_length,
            max_length=max_length,
            pattern=pattern,
            pattern_mode=pattern_mode,
            rack=rack,
        )
        return self.sort_words(filtered, mode=sort)
