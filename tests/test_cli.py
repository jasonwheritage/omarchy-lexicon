import io
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest.mock import patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "src")))

from cli import main


class CliTests(unittest.TestCase):
    def test_reads_defaults_from_config_file(self):
        with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as words_file:
            words_file.write("quiz\napple\npear\n")
            words_path = words_file.name
        with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as config_file:
            config_file.write(f"WORDLIST_PATH={words_path}\n")
            config_file.write("SORT_MODE=score_desc\n")
            config_path = config_file.name

        out = io.StringIO()
        err = io.StringIO()
        try:
            with redirect_stdout(out), redirect_stderr(err):
                code = main(["--config", config_path])
            self.assertEqual(code, 0)
            self.assertEqual(out.getvalue().strip().splitlines(), ["quiz", "apple", "pear"])
            self.assertEqual(err.getvalue().strip(), "")
        finally:
            os.unlink(words_path)
            os.unlink(config_path)

    @patch("cli.DictionaryLookup")
    def test_direct_lookup_uses_configured_databases(self, lookup_class):
        lookup_class.return_value.lookup.return_value = {"definition": "meaning"}
        lookup_class.return_value.similar.return_value = {"definition": "related"}
        with tempfile.NamedTemporaryFile("w", encoding="utf-8") as config:
            config.write("DICTIONARY_DATABASE=gcide\nTHESAURUS_DATABASE=moby-thesaurus\n")
            config.flush()
            out = io.StringIO()
            with redirect_stdout(out):
                code = main(["--config", config.name, "--lookup-word", "apple", "--definition", "--synonyms"])
        self.assertEqual(code, 0)
        lookup_class.assert_called_once_with(database="gcide", thesaurus="moby-thesaurus")
        self.assertIn("meaning", out.getvalue())
        self.assertIn("related", out.getvalue())

    @patch("cli.DictionaryLookup")
    def test_lookup_cli_options_override_environment_and_config(self, lookup_class):
        lookup_class.return_value.lookup.return_value = {"definition": "meaning"}
        with tempfile.NamedTemporaryFile("w", encoding="utf-8") as config:
            config.write("DICTIONARY_DATABASE=wn\nTHESAURUS_DATABASE=moby-thesaurus\n")
            config.flush()
            with patch.dict(os.environ, {"LEXICON_DICTIONARY": "environment-db", "LEXICON_THESAURUS": "environment-thesaurus"}), redirect_stdout(io.StringIO()):
                code = main(["--config", config.name, "--lookup-word", "apple", "--definition", "--dictionary", "gcide"])
        self.assertEqual(code, 0)
        lookup_class.assert_called_once_with(database="gcide", thesaurus="environment-thesaurus")

    def test_rejects_invalid_length_range(self):
        out = io.StringIO()
        err = io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = main(["--min-length", "7", "--max-length", "3", "--from-stdin"])
        self.assertEqual(code, 2)
        self.assertIn("--min-length cannot be greater than --max-length", err.getvalue())

    def test_rejects_invalid_regex_pattern(self):
        out = io.StringIO()
        err = io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = main(["--from-stdin", "--pattern", "(", "--pattern-mode", "regex"])
        self.assertEqual(code, 2)
        self.assertIn("Invalid regular expression", err.getvalue())
        self.assertIn("missing", err.getvalue().lower())


if __name__ == "__main__":
    unittest.main()
