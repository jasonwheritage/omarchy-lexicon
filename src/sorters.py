from __future__ import annotations

from typing import Iterable, List

from lexicon_core import score_word


def sort_words(words: Iterable[str], mode: str = "alpha") -> List[str]:
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
