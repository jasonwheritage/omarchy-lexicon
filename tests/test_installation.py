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

    def test_install_script_installs_runnable_cli_and_config(self):
        prefix = self.root / "prefix"
        env = dict(self.env, PREFIX=str(prefix), KEYBIND_TARGET_DIR=str(self.root / "missing"))
        subprocess.run([str(ROOT / "install.sh")], cwd=self.root, env=env, check=True, capture_output=True)
        self.check_cli(prefix)
        config = prefix / "etc/omarchy-lexicon/default.conf"
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


if __name__ == "__main__":
    unittest.main()
