import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "src")))

from lexicon_core import WordFinder


class WordFinderTests(unittest.TestCase):
    def setUp(self):
        self.words = ["apple", "grape", "orange", "pear", "plum", "stare", "tares", "tears", "rates"]
        self.tempfile = tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8")
        for word in self.words:
            self.tempfile.write(f"{word}\n")
        self.tempfile.close()

    def tearDown(self):
        os.unlink(self.tempfile.name)

    def test_exact_length_filter(self):
        finder = WordFinder(self.tempfile.name)
        result = finder.filter_words(self.words, length=5)
        self.assertEqual(result, ["apple", "grape", "stare", "tares", "tears", "rates"])

    def test_pattern_filter(self):
        finder = WordFinder(self.tempfile.name)
        result = finder.filter_words(self.words, pattern="a..le")
        self.assertEqual(result, ["apple"])

    def test_rack_filter(self):
        finder = WordFinder(self.tempfile.name)
        result = finder.filter_words(self.words, rack="aerst")
        self.assertEqual(set(result), {"stare", "rates", "tears", "tares"})

    def test_sort_mode(self):
        finder = WordFinder(self.tempfile.name)
        result = finder.sort_words(["pear", "apple", "orange"], mode="length_asc")
        self.assertEqual(result, ["pear", "apple", "orange"])


if __name__ == "__main__":
    unittest.main()
