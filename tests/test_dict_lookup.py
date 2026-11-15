import os
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "src")))

from dict_lookup import DictionaryLookup


class DictionaryLookupTests(unittest.TestCase):
    def test_lookup_gracefully_handles_missing_binary(self):
        lookup = DictionaryLookup(command="does-not-exist")
        result = lookup.lookup("apple")
        self.assertFalse(result["available"])
        self.assertIn("Dictionary", result["definition"])
        self.assertNotIn("dict-wn", result["definition"])

    @patch("dict_lookup.shutil.which", return_value="/usr/bin/dict")
    @patch("dict_lookup.subprocess.run")
    def test_selected_databases_are_used(self, run, which):
        run.return_value = subprocess.CompletedProcess([], 0, "definition", "")
        lookup = DictionaryLookup(database="gcide", thesaurus="custom")
        self.assertTrue(lookup.lookup("apple")["available"])
        self.assertEqual(run.call_args.args[0], ["dict", "-h", "localhost", "-d", "gcide", "--", "apple"])
        self.assertTrue(lookup.similar("apple")["available"])
        self.assertEqual(run.call_args.args[0], ["dict", "-h", "localhost", "-d", "custom", "--", "apple"])

    @patch("dict_lookup.shutil.which", return_value="/usr/bin/dict")
    @patch("dict_lookup.subprocess.run")
    def test_lookup_failure_and_timeout_are_reported(self, run, which):
        run.return_value = subprocess.CompletedProcess([], 1, "", "connection refused")
        result = DictionaryLookup().lookup("apple")
        self.assertFalse(result["available"])
        self.assertIn("connection refused", result["definition"])
        run.side_effect = subprocess.TimeoutExpired("dict", 5)
        self.assertIn("timed out", DictionaryLookup().similar("apple")["definition"])


if __name__ == "__main__":
    unittest.main()
