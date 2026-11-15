import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "src")))

from dict_lookup import DictionaryLookup


class DictionaryLookupTests(unittest.TestCase):
    def test_lookup_gracefully_handles_missing_binary(self):
        lookup = DictionaryLookup(command="does-not-exist")
        result = lookup.lookup("apple")
        self.assertFalse(result["available"])
        self.assertIn("Dictionary", result["definition"])


if __name__ == "__main__":
    unittest.main()
