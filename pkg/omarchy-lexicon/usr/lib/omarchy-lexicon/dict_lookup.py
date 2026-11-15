from __future__ import annotations

import shutil
import subprocess
from typing import Any, Dict


class DictionaryLookup:
    def __init__(self, command: str = "dict", database: str = "wn") -> None:
        self.command = command
        self.database = database

    def available(self) -> bool:
        return shutil.which(self.command) is not None

    def lookup(self, word: str) -> Dict[str, Any]:
        if not self.available():
            return {
                "available": False,
                "word": word,
                "definition": "Dictionary service unavailable. Install dictd and dict-wn for offline definitions.",
            }

        try:
            result = subprocess.run(
                [self.command, "-d", self.database, word],
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            return {
                "available": False,
                "word": word,
                "definition": "Dictionary service did not respond in time.",
            }

        output = (result.stdout or "") + "\n" + (result.stderr or "")
        text = output.strip()
        return {
            "available": True,
            "word": word,
            "definition": text or "No definition found for this word.",
        }
