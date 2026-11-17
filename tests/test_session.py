import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SESSION_PATH = ROOT / "plugins" / "acme.lexicon" / "session.js"


def run_session(script: str):
    source = SESSION_PATH.read_text(encoding="utf-8")
    if source.startswith(".pragma library"):
        source = source.split("\n", 1)[1]
    result = subprocess.run(
        ["qjs", "-e", source + "\n" + script],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout)
    return json.loads(result.stdout)


class SessionTests(unittest.TestCase):
    def test_exit_saves_only_nonempty_searches_and_keeps_three(self):
        payload = run_session(r"""
var ring = []
var first = rememberOnExit(ring, {pattern:"one", length:0, rack:false, descending:false, selectedWord:"one", thesaurusWord:""})
var second = rememberOnExit(first.history, {pattern:"two", length:4, rack:true, descending:true, selectedWord:"two", thesaurusWord:"too"})
var third = rememberOnExit(second.history, {pattern:"three", length:0, rack:false, descending:false, selectedWord:"", thesaurusWord:""})
var fourth = rememberOnExit(third.history, {pattern:"four", length:0, rack:false, descending:false, selectedWord:"", thesaurusWord:""})
var blank = rememberOnExit(fourth.history, {pattern:"  ", length:2, rack:true, descending:true, selectedWord:"", thesaurusWord:""})
var repeat = rememberOnExit(fourth.history, {pattern:"four", length:0, rack:false, descending:false, selectedWord:"fore", thesaurusWord:""})
print(JSON.stringify({
  fourth: fourth.history.map(function(item) { return item.pattern }),
  fourthCursor: fourth.cursor,
  blankCount: blank.history.length,
  blankCursor: blank.cursor,
  blankPattern: blank.current.pattern,
  repeatWord: repeat.history[repeat.history.length - 1].selectedWord,
  repeatCount: repeat.history.length
}))
""")
        self.assertEqual(payload["fourth"], ["two", "three", "four"])
        self.assertEqual(payload["fourthCursor"], 2)
        self.assertEqual(payload["blankCount"], 3)
        self.assertEqual(payload["blankCursor"], -1)
        self.assertEqual(payload["blankPattern"], "")
        self.assertEqual(payload["repeatWord"], "fore")
        self.assertEqual(payload["repeatCount"], 3)

    def test_down_on_the_newest_search_applies_defaults(self):
        payload = run_session(r"""
var saved = rememberOnExit([], {pattern:"apple", length:5, rack:true, descending:true, selectedWord:"apple", thesaurusWord:""})
var older = rememberOnExit(saved.history, {pattern:"pear", length:0, rack:false, descending:false, selectedWord:"pear", thesaurusWord:""})
var newest = moveHistory(older.history, 0, "down")
var defaults = moveHistory(older.history, newest.cursor, "down")
var again = moveHistory(older.history, defaults.cursor, "down")
var back = moveHistory(older.history, again.cursor, "up")
var stay = moveHistory(older.history, 0, "up")
print(JSON.stringify({
  newest: newest.session.pattern,
  defaultsPattern: defaults.session.pattern,
  defaultsLength: defaults.session.length,
  defaultsRack: defaults.session.rack,
  defaultsDescending: defaults.session.descending,
  defaultsCursor: defaults.cursor,
  again: again.cursor,
  back: back.session.pattern,
  stay: stay.session.pattern
}))
""")
        self.assertEqual(payload["newest"], "pear")
        self.assertEqual(payload["defaultsPattern"], "")
        self.assertEqual(payload["defaultsLength"], 0)
        self.assertFalse(payload["defaultsRack"])
        self.assertFalse(payload["defaultsDescending"])
        self.assertEqual(payload["defaultsCursor"], -1)
        self.assertEqual(payload["again"], -1)
        self.assertEqual(payload["back"], "pear")
        self.assertEqual(payload["stay"], "apple")

    def test_rack_search_uses_letters_without_a_spelling_pattern(self):
        payload = run_session(r"""
var engaged = applyRack(5, true)
var args = searchArgs("ppale", engaged.length, engaged.rack, false)
var kept = searchArgs("a??le", 4, false, true)
var byLenAsc = searchArgs("ppale", 0, true, false, true)
var byLenDesc = searchArgs("ppale", 0, true, true, true)
print(JSON.stringify({
  length: engaged.length,
  rack: engaged.rack,
  query: args.query,
  letters: args.rack,
  patternQuery: kept.query,
  patternRack: kept.rack,
  patternSort: kept.sort,
  byLenAsc: byLenAsc.sort,
  byLenDesc: byLenDesc.sort
}))
""")
        self.assertEqual(payload["length"], 0)
        self.assertTrue(payload["rack"])
        self.assertEqual(payload["query"], "")
        self.assertEqual(payload["letters"], "ppale")
        self.assertEqual(payload["patternQuery"], "a??le")
        self.assertEqual(payload["patternRack"], "")
        self.assertEqual(payload["patternSort"], "alpha_desc")
        self.assertEqual(payload["byLenAsc"], "length_asc")
        self.assertEqual(payload["byLenDesc"], "length_desc")

    def test_appearance_stays_out_of_saved_searches(self):
        payload = run_session(r"""
var session = cloneSession({pattern:"apple", length:5, rack:true, descending:false, selectedWord:"apple", font:"Noto Sans", scale:1.4})
var state = normalizeState({history:[session], current:session, cursor:0, appearance:{font:"Noto Sans", scale:1.4}})
var appearance = normalizeAppearance({font:"Comic Sans", scale:9})
var grown = stepScale(1, 1)
var shrunk = stepScale(0.8, -1)
var font = cycleFont("theme", 1)
var back = cycleFont(font, -1)
print(JSON.stringify({
  sessionFont: session.font || "",
  sessionScale: session.scale || 0,
  statePattern: state.current.pattern,
  appearanceFont: appearance.font,
  appearanceScale: appearance.scale,
  grown: grown,
  shrunk: shrunk,
  font: font,
  back: back
}))
""")
        self.assertEqual(payload["sessionFont"], "")
        self.assertEqual(payload["sessionScale"], 0)
        self.assertEqual(payload["statePattern"], "apple")
        self.assertEqual(payload["appearanceFont"], "Comic Sans")
        self.assertEqual(payload["appearanceScale"], 2)
        self.assertEqual(payload["grown"], 1.25)
        self.assertEqual(payload["shrunk"], 0.75)
        self.assertEqual(payload["font"], "Liberation Sans")
        self.assertEqual(payload["back"], "theme")

    def test_rack_letters_keep_exact_counts_and_drop_wildcards(self):
        payload = run_session(r"""
print(JSON.stringify(rackLetters("Ap?e*")))
""")
        self.assertEqual(payload, "ape")


if __name__ == "__main__":
    unittest.main()
