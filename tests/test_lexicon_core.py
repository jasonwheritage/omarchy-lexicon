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

    def test_pattern_substring_filter(self):
        finder = WordFinder(self.tempfile.name)
        result = finder.filter_words(self.words, pattern="ang", pattern_mode="substring")
        self.assertEqual(result, ["orange"])

    def test_pattern_regex_filter(self):
        finder = WordFinder(self.tempfile.name)
        result = finder.filter_words(self.words, pattern="^t.*s$", pattern_mode="regex")
        self.assertEqual(result, ["tares", "tears"])

    def test_rack_filter(self):
        finder = WordFinder(self.tempfile.name)
        result = finder.filter_words(self.words, rack="aerst")
        self.assertEqual(set(result), {"stare", "rates", "tears", "tares"})

    def test_rack_keeps_repeated_letters(self):
        finder = WordFinder(self.tempfile.name)
        result = finder.filter_words(["apple", "pale", "ape", "apply"], rack="ppale")
        self.assertIn("apple", result)
        self.assertIn("pale", result)
        self.assertNotIn("apply", result)

    def test_rack_count_limits_every_pattern_mode(self):
        finder = WordFinder(self.tempfile.name)
        words = ["apple", "ape", "pale", "apply", "plea"]
        bare = finder.filter_words(words, rack="aple")
        self.assertNotIn("apple", bare)
        self.assertIn("pale", bare)
        cases = (
            ("substring", "ap"),
            ("wildcard", "ap*"),
            ("regex", "ap"),
            ("auto", "ap*"),
        )
        for mode, pattern in cases:
            result = finder.filter_words(words, pattern=pattern, pattern_mode=mode, rack="aple")
            self.assertNotIn("apple", result, mode)
            self.assertIn("ape", result, mode)

    def test_alpha_desc_reverses_alpha(self):
        finder = WordFinder(self.tempfile.name)
        result = finder.sort_words(["pear", "apple", "orange"], mode="alpha_desc")
        self.assertEqual(result, ["pear", "orange", "apple"])

    def test_sort_mode(self):
        finder = WordFinder(self.tempfile.name)
        result = finder.sort_words(["pear", "apple", "orange"], mode="length_asc")
        self.assertEqual(result, ["pear", "apple", "orange"])
        desc_result = finder.sort_words(["pear", "apple", "orange"], mode="length_desc")
        self.assertEqual(desc_result, ["orange", "apple", "pear"])

    def test_min_max_length_filter(self):
        finder = WordFinder(self.tempfile.name)
        result = finder.filter_words(self.words, min_length=5, max_length=5)
        self.assertEqual(result, ["apple", "grape", "stare", "tares", "tears", "rates"])

    def test_score_sort_mode(self):
        finder = WordFinder(self.tempfile.name)
        result = finder.sort_words(["quiz", "apple", "pear"], mode="score_desc")
        self.assertEqual(result, ["quiz", "apple", "pear"])


if __name__ == "__main__":
    unittest.main()
