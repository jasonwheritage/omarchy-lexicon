import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class WalkerLookupTests(unittest.TestCase):
    def test_selected_word_uses_configured_databases(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name, body in {
                "walker": "cat >/dev/null\nprintf 'apple\\n'\n",
                "wl-copy": "cat >/dev/null\n",
                "dict": "printf 'database=%s word=%s\\n' \"$4\" \"$6\"\n",
            }.items():
                executable = root / name
                executable.write_text("#!/bin/sh\n" + body, encoding="utf-8")
                executable.chmod(0o755)
            wordlist = root / "words"
            wordlist.write_text("apple\n", encoding="utf-8")
            config = root / "config"
            config.write_text(
                f"WORDLIST_PATH={wordlist}\nDICTIONARY_DATABASE=gcide\n"
                "THESAURUS_DATABASE=custom-thesaurus\n",
                encoding="utf-8",
            )
            env = {key: value for key, value in os.environ.items() if not key.startswith("LEXICON_")}
            env.update(PATH=f"{root}:/usr/bin:/bin", LEXICON_CONFIG=str(config), LEXICON_SYNONYMS="1", PYTHONDONTWRITEBYTECODE="1")
            result = subprocess.run(
                [str(ROOT / "bin" / "omarchy-lexicon-walker")],
                env=env, text=True, capture_output=True, check=False,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("database=gcide word=apple", result.stdout)
        self.assertIn("database=custom-thesaurus word=apple", result.stdout)


if __name__ == "__main__":
    unittest.main()
