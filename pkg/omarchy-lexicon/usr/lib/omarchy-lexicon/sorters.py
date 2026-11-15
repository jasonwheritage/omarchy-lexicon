from __future__ import annotations

from typing import Iterable, List


def sort_words(words: Iterable[str], mode: str = "alpha") -> List[str]:
    ordered = sorted(set(words))
    if mode == "length_asc":
        return sorted(ordered, key=lambda item: (len(item), item))
    if mode == "length_desc":
        return sorted(ordered, key=lambda item: (-len(item), item))
    return ordered
