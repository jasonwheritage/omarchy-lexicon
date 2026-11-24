import importlib.util
import io
import json
import os
import subprocess
import tempfile
import unittest
from argparse import Namespace
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parent.parent
SEARCH_PATH = ROOT / "plugins" / "acme.lexicon" / "search.py"


def load_search():
    spec = importlib.util.spec_from_file_location("lexicon_search", SEARCH_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class SearchGatewayTests(unittest.TestCase):
    def test_query_fields_become_search_parameters(self):
        search = load_search()
        args = Namespace(
            query="s.a.e len=5 rack=aeinrst min=4 max=8",
            length=None,
            min_length=None,
            max_length=None,
            rack="",
            pattern_mode="auto",
            sort="alpha",
            limit=10,
            wordlist="/usr/share/dict/words",
            config=None,
        )
        params = search._resolve_search_params(args, {})
        self.assertEqual(params["pattern"], "s.a.e")
        self.assertEqual(params["length"], 5)
        self.assertEqual(params["rack"], "aeinrst")
        self.assertEqual(params["min_length"], 4)
        self.assertEqual(params["max_length"], 8)

    def test_rack_letters_are_a_pool_not_a_spelling(self):
        search = load_search()
        args = Namespace(
            query="ppale",
            length=None,
            min_length=None,
            max_length=None,
            rack="ppale",
            pattern_mode="auto",
            sort="alpha",
            limit=80,
            wordlist="/usr/share/dict/words",
            config=None,
        )
        params = search._resolve_search_params(args, {})
        self.assertIsNone(params["pattern"])
        self.assertEqual(params["rack"], "ppale")

    def test_explicit_flags_win_over_query_fields(self):
        search = load_search()
        args = Namespace(
            query="len=5 rack=abc",
            length=7,
            min_length=None,
            max_length=None,
            rack="zzzz",
            pattern_mode="substring",
            sort="alpha",
            limit=5,
            wordlist="/usr/share/dict/words",
            config=None,
        )
        params = search._resolve_search_params(args, {})
        self.assertIsNone(params["pattern"])
        self.assertEqual(params["length"], 7)
        self.assertEqual(params["rack"], "zzzz")

    def test_reads_defaults_from_config_file(self):
        search = load_search()
        with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as words_file:
            words_file.write("quiz\napple\npear\n")
            words_path = words_file.name
        with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as config_file:
            config_file.write(f"WORDLIST_PATH={words_path}\n")
            config_file.write("SORT_MODE=score_desc\n")
            config_path = config_file.name

        out = io.StringIO()
        try:
            with redirect_stdout(out):
                code = search.main(["--config", config_path])
            self.assertEqual(code, 0)
            payload = json.loads(out.getvalue())
            self.assertTrue(payload["ok"])
            self.assertEqual(payload["results"], ["quiz", "apple", "pear"])
        finally:
            os.unlink(words_path)
            os.unlink(config_path)

    def test_lookup_uses_configured_and_overridden_databases(self):
        search = load_search()
        with tempfile.NamedTemporaryFile("w", encoding="utf-8") as config:
            config.write("DICTIONARY_DATABASE=gcide\nTHESAURUS_DATABASE=custom-thesaurus\n")
            config.flush()
            with patch.object(search, "lookup_definition", return_value={"ok": True, "word": "apple", "text": "meaning"}) as mock_def:
                out = io.StringIO()
                with redirect_stdout(out):
                    code = search.main(["--config", config.name, "--definition", "apple"])
                self.assertEqual(code, 0)
                mock_def.assert_called_once_with("apple", database="gcide")

            with patch.object(search, "lookup_thesaurus", return_value={"ok": True, "word": "apple", "results": ["pome"]}) as mock_thes:
                out = io.StringIO()
                with redirect_stdout(out):
                    code = search.main(["--config", config.name, "--thesaurus", "apple", "--thesaurus-db", "moby-thesaurus"])
                self.assertEqual(code, 0)
                mock_thes.assert_called_once_with("apple", database="moby-thesaurus")

    def test_rejects_invalid_length_range_and_regex(self):
        search = load_search()
        out = io.StringIO()
        with redirect_stdout(out):
            code = search.main(["--min-length", "7", "--max-length", "3"])
        self.assertEqual(code, 2)
        self.assertIn("--min-length cannot be greater than --max-length", json.loads(out.getvalue())["error"])

        with tempfile.NamedTemporaryFile("w", encoding="utf-8") as words_file:
            words_file.write("apple\n")
            words_file.flush()
            out = io.StringIO()
            with redirect_stdout(out):
                code = search.main(["--wordlist", words_file.name, "--query", "(", "--pattern-mode", "regex"])
            self.assertEqual(code, 2)
            self.assertIn("Invalid regular expression", json.loads(out.getvalue())["error"])

    def test_gateway_searches_directly_without_cli_binary(self):
        with tempfile.NamedTemporaryFile("w", encoding="utf-8") as words_file:
            words_file.write("anarchy\nmonarchy\napple\n")
            words_file.flush()
            env = dict(os.environ, PATH="/usr/bin:/bin", PYTHONDONTWRITEBYTECODE="1")
            result = subprocess.run(
                ["python3", str(SEARCH_PATH), "--wordlist", words_file.name, "--query", "archy", "--limit", "5"],
                text=True,
                capture_output=True,
                env=env,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            payload = json.loads(result.stdout)
            self.assertEqual(payload["results"], ["anarchy", "monarchy"])

    def test_thesaurus_text_becomes_words(self):
        search = load_search()
        text = """
1 definition found

From Moby Thesaurus II by Grady Ward, 1.0 [moby-thesaurus]:

  4 Moby Thesaurus words for "happy":
     bright and sunny, glad, joyful, beaming
"""
        words = search.parse_thesaurus_text(text, "happy")
        self.assertEqual(words, ["bright", "sunny", "glad", "joyful", "beaming"])

    def _fake_dict(self, search, outputs):
        def run(database, word):
            return outputs[(database, word)]
        return patch.object(search, "_run_dict", side_effect=run), patch.object(search.shutil, "which", return_value="/usr/bin/dict")

    def test_missing_definition_follows_closest_entry(self):
        search = load_search()
        miss = 'No definitions found for "flamethrowers", perhaps you mean:\nwn:  flamethrower  flamethrowing'
        hit = '1 definition found\n\nFrom WordNet (r) 3.0 (2006) [wn]:\n\n  flamethrower\n      n 1: a weapon that squirts ignited fuel'
        runner, which = self._fake_dict(search, {
            ("wn", "flamethrowers"): (21, "", miss),
            ("wn", "flamethrower"): (0, hit, hit),
        })
        with runner, which:
            payload = search.lookup_definition("flamethrowers")
        self.assertTrue(payload["ok"])
        self.assertTrue(payload["found"])
        self.assertEqual(payload["closest"], "flamethrower")
        self.assertEqual(payload["text"], "n 1: a weapon that squirts ignited fuel")

    def test_unknown_word_has_no_raw_dict_text(self):
        search = load_search()
        miss = 'No definitions found for "xqzzv"'
        runner, which = self._fake_dict(search, {("wn", "xqzzv"): (20, "", miss)})
        with runner, which:
            payload = search.lookup_definition("xqzzv")
        self.assertEqual(payload, {"ok": True, "word": "xqzzv", "text": "", "found": False})

    def test_missing_thesaurus_entry_does_not_leak_message_words(self):
        search = load_search()
        miss = 'No definitions found for "flamethrowers", perhaps you mean:\nmoby-thesaurus:  flamethrower'
        hit = '1 definition found\n\nFrom Moby Thesaurus II by Grady Ward, 1.0 [moby-thesaurus]:\n\n  2 Moby Thesaurus words for "flamethrower":\n     gun, pistol'
        runner, which = self._fake_dict(search, {
            ("moby-thesaurus", "flamethrowers"): (21, "", miss),
            ("moby-thesaurus", "flamethrower"): (0, hit, hit),
        })
        with runner, which:
            payload = search.lookup_thesaurus("flamethrowers")
        self.assertEqual(payload["results"], ["gun", "pistol"])
        self.assertEqual(payload["closest"], "flamethrower")

    def test_thesaurus_without_suggestions_is_empty(self):
        search = load_search()
        miss = 'No definitions found for "xqzzv"'
        runner, which = self._fake_dict(search, {("moby-thesaurus", "xqzzv"): (20, "", miss)})
        with runner, which:
            payload = search.lookup_thesaurus("xqzzv")
        self.assertEqual(payload["results"], [])
        self.assertTrue(payload["ok"])


if __name__ == "__main__":
    unittest.main()
