import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class InstallationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith("LEXICON_") and key != "PYTHONPATH"}
        self.env.update(PYTHONDONTWRITEBYTECODE="1", HOME=str(self.root), PATH="/usr/bin:/bin")

    def check_cli(self, prefix, extra_args=()):
        result = subprocess.run(
            [str(prefix / "bin/omarchy-lexicon"), "--from-stdin", *extra_args],
            input="apple\n", text=True, capture_output=True, cwd=self.root, env=self.env,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "apple\n")

    def check_walker(self, prefix, config):
        fake_bin = self.root / "fake-bin"
        fake_bin.mkdir()
        for name, body in {
            "walker": "cat >/dev/null\nprintf 'apple\\n'\n",
            "wl-copy": "cat >/dev/null\n",
            "dict": "printf 'database=%s word=%s\\n' \"$4\" \"$6\"\n",
        }.items():
            command = fake_bin / name
            command.write_text("#!/bin/sh\n" + body, encoding="utf-8")
            command.chmod(0o755)
        words = self.root / "words"
        words.write_text("apple\n", encoding="utf-8")
        env = dict(self.env, PATH=f"{fake_bin}:/usr/bin:/bin", LEXICON_WORDLIST=str(words),
                   LEXICON_CONFIG=str(config), LEXICON_SYNONYMS="1")
        result = subprocess.run([str(prefix / "bin/omarchy-lexicon-walker")],
                                text=True, capture_output=True, cwd=self.root, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("database=wn word=apple", result.stdout)
        self.assertIn("database=moby-thesaurus word=apple", result.stdout)

    def test_install_script_installs_runnable_cli_and_config(self):
        prefix = self.root / "prefix"
        env = dict(self.env, PREFIX=str(prefix), KEYBIND_TARGET_DIR=str(self.root / "missing"))
        subprocess.run([str(ROOT / "install.sh")], cwd=self.root, env=env, check=True, capture_output=True)
        self.check_cli(prefix)
        config = prefix / "etc/omarchy-lexicon/default.conf"
        self.check_walker(prefix, config)
        config.write_text("DEFAULT_LENGTH=4\n", encoding="utf-8")
        result = subprocess.run([str(prefix / "bin/omarchy-lexicon"), "--from-stdin"],
                                input="apple\npear\n", text=True, capture_output=True,
                                cwd=self.root, env=self.env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "pear\n")

    def test_pkgbuild_installs_runnable_cli(self):
        srcdir = self.root / "source"
        srcdir.mkdir()
        (srcdir / "omarchy-lexicon").symlink_to(ROOT, target_is_directory=True)
        pkgdir = self.root / "package"
        env = dict(self.env, srcdir=str(srcdir), pkgdir=str(pkgdir))
        subprocess.run(["bash", "-c", 'source "$1"; package', "bash", str(ROOT / "PKGBUILD")],
                       cwd=self.root, env=env, check=True, capture_output=True)
        config = pkgdir / "etc/omarchy-lexicon/default.conf"
        self.check_cli(pkgdir / "usr", ("--config", str(config)))
        self.check_walker(pkgdir / "usr", config)


if __name__ == "__main__":
    unittest.main()
