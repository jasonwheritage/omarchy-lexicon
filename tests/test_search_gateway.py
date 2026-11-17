import importlib.util
import os
import subprocess
import tempfile
import unittest
from argparse import Namespace
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SEARCH_PATH = ROOT / "plugins" / "acme.lexicon" / "search.py"


def load_search():
    spec = importlib.util.spec_from_file_location("lexicon_search", SEARCH_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class SearchGatewayTests(unittest.TestCase):
    def test_query_fields_become_backend_arguments(self):
        search = load_search()
        search._resolve_backend = lambda: "omarchy-lexicon"
        args = Namespace(
            query="s.a.e len=5 rack=aeinrst min=4 max=8",
            length=None,
            min_length=None,
            max_length=None,
            rack="",
            pattern_mode="auto",
            sort="alpha",
            limit=10,
        )
        command = search._build_command(args)
        self.assertIn("--pattern", command)
        self.assertEqual(command[command.index("--pattern") + 1], "s.a.e")
        self.assertEqual(command[command.index("--length") + 1], "5")
        self.assertEqual(command[command.index("--rack") + 1], "aeinrst")
        self.assertEqual(command[command.index("--min-length") + 1], "4")
        self.assertEqual(command[command.index("--max-length") + 1], "8")

    def test_explicit_flags_win_over_query_fields(self):
        search = load_search()
        search._resolve_backend = lambda: "omarchy-lexicon"
        args = Namespace(
            query="len=5 rack=abc",
            length=7,
            min_length=None,
            max_length=None,
            rack="zzzz",
            pattern_mode="substring",
            sort="alpha",
            limit=5,
        )
        command = search._build_command(args)
        self.assertNotIn("--pattern", command)
        self.assertEqual(command[command.index("--length") + 1], "7")
        self.assertEqual(command[command.index("--rack") + 1], "zzzz")

    def test_home_local_backend_is_used_when_path_omits_it(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            plugin = home / ".config" / "omarchy" / "plugins" / "acme.lexicon"
            plugin.mkdir(parents=True)
            installed = plugin / "search.py"
            installed.write_text(SEARCH_PATH.read_text(encoding="utf-8"), encoding="utf-8")
            binary = home / ".local" / "bin" / "omarchy-lexicon"
            binary.parent.mkdir(parents=True)
            binary.write_text("#!/bin/sh\n", encoding="utf-8")
            binary.chmod(0o755)
            spec = importlib.util.spec_from_file_location("installed_lexicon_search", installed)
            search = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(search)
            previous = os.environ.get("HOME")
            os.environ["HOME"] = str(home)
            path = os.environ.get("PATH", "")
            os.environ["PATH"] = "/usr/bin:/bin"
            try:
                self.assertEqual(search._resolve_backend(), str(binary))
            finally:
                if previous is None:
                    os.environ.pop("HOME", None)
                else:
                    os.environ["HOME"] = previous
                os.environ["PATH"] = path

    def test_installed_gateway_searches_without_path_entry(self):
        binary = Path.home() / ".local" / "bin" / "omarchy-lexicon"
        if not binary.is_file():
            self.skipTest("user-local omarchy-lexicon is not installed")
        env = dict(os.environ, PATH="/usr/bin:/bin", PYTHONDONTWRITEBYTECODE="1")
        result = subprocess.run(
            ["python3", str(SEARCH_PATH), "--query", "archy", "--limit", "5"],
            text=True,
            capture_output=True,
            env=env,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("anarchy", result.stdout)


if __name__ == "__main__":
    unittest.main()
