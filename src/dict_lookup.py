from __future__ import annotations

import shutil
import subprocess
from typing import Any, Dict


class DictionaryLookup:
    def __init__(self, command: str = "dict", database: str = "wn", thesaurus: str = "moby-thesaurus") -> None:
        self.command = command
        self.database = database
        self.thesaurus = thesaurus

    def available(self) -> bool:
        return shutil.which(self.command) is not None

    def lookup(self, word: str) -> Dict[str, Any]:
        return self._lookup(word, self.database)

    def similar(self, word: str) -> Dict[str, Any]:
        return self._lookup(word, self.thesaurus)

    def _lookup(self, word: str, database: str) -> Dict[str, Any]:
        if not self.available():
            return {
                "available": False,
                "word": word,
                "definition": "Dictionary lookup unavailable: install dictd and configure a local database.",
            }

        try:
            result = subprocess.run(
                [self.command, "-h", "localhost", "-d", database, "--", word],
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            return {
                "available": False,
                "word": word,
                "definition": "Dictionary lookup failed or timed out; check the local dictd service.",
            }

        output = (result.stdout or "") + "\n" + (result.stderr or "")
        text = output.strip()
        if result.returncode != 0:
            return {
                "available": False,
                "word": word,
                "definition": f"Dictionary lookup failed for database '{database}': {text or 'check the local dictd service.'}",
            }
        return {
            "available": True,
            "word": word,
            "definition": text or "No definition found for this word.",
        }
