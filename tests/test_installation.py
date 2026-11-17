import json
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
        self.words_file = self.root / "words.txt"
        self.words_file.write_text("apple\npear\nplum\n", encoding="utf-8")
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith("LEXICON_") and key not in {"PYTHONPATH", "XDG_CONFIG_HOME"}}
        self.env.update(PYTHONDONTWRITEBYTECODE="1", HOME=str(self.root), PATH="/usr/bin:/bin")

    def check_plugin_search(self, plugin_dir: Path, extra_args=()):
        result = subprocess.run(
            ["python3", str(plugin_dir / "search.py"), "--wordlist", str(self.words_file), *extra_args],
            text=True,
            capture_output=True,
            cwd=self.root,
            env=self.env,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        return json.loads(result.stdout)

    def test_install_script_installs_self_contained_plugin_without_cli(self):
        prefix = self.root / "prefix"
        plugin_target = self.root / "plugin"
        env = dict(self.env, PREFIX=str(prefix), PLUGIN_TARGET_DIR=str(plugin_target))
        subprocess.run([str(ROOT / "install.sh")], cwd=self.root, env=env, check=True, capture_output=True)

        self.assertFalse((prefix / "bin" / "omarchy-lexicon").exists())
        self.assertTrue((plugin_target / "manifest.json").exists())
        self.assertTrue((plugin_target / "LexiconOverlay.qml").exists())
        self.assertTrue((plugin_target / "search.py").exists())
        self.assertTrue((plugin_target / "session.js").exists())
        self.assertTrue((plugin_target / "lexicon_core.py").exists())
        self.assertTrue((plugin_target / "i18n" / "en.json").exists())

        config = prefix / "etc" / "omarchy-lexicon" / "default.conf"
        config.write_text(f"WORDLIST_PATH={self.words_file}\nDEFAULT_LENGTH=4\n", encoding="utf-8")
        payload = self.check_plugin_search(plugin_target, ("--config", str(config)))
        self.assertEqual(payload["results"], ["pear", "plum"])

    def test_install_script_defaults_to_user_plugin_dir(self):
        home = self.root / "home"
        home.mkdir()
        env = dict(self.env, HOME=str(home), PREFIX=str(home / ".local"))
        subprocess.run([str(ROOT / "install.sh")], cwd=self.root, env=env, check=True, capture_output=True)

        self.assertFalse((home / ".local" / "bin" / "omarchy-lexicon").exists())
        plugin_dir = home / ".config" / "omarchy" / "plugins" / "acme.lexicon"
        self.assertTrue((plugin_dir / "manifest.json").exists())
        self.assertTrue((plugin_dir / "lexicon_core.py").exists())

    def test_install_script_respects_xdg_config_home_and_destdir(self):
        home = self.root / "home"
        xdg = self.root / "xdg"
        env = dict(self.env, HOME=str(home), XDG_CONFIG_HOME=str(xdg), PREFIX=str(self.root / "prefix"))
        subprocess.run([str(ROOT / "install.sh")], cwd=self.root, env=env, check=True, capture_output=True)
        self.assertTrue((xdg / "omarchy" / "plugins" / "acme.lexicon" / "manifest.json").exists())

        destdir = self.root / "staging"
        env = dict(self.env, HOME=str(home), DESTDIR=str(destdir), PREFIX="/usr/local")
        subprocess.run([str(ROOT / "install.sh")], cwd=self.root, env=env, check=True, capture_output=True)
        staged_plugin = destdir / "usr" / "local" / "share" / "omarchy-lexicon" / "plugins" / "acme.lexicon"
        self.assertTrue((staged_plugin / "manifest.json").exists())
        self.assertTrue((staged_plugin / "search.py").exists())
        self.assertTrue((staged_plugin / "lexicon_core.py").exists())
        self.assertFalse((destdir / "usr" / "local" / "bin" / "omarchy-lexicon").exists())
        self.assertFalse((home / ".config" / "omarchy" / "plugins" / "acme.lexicon").exists())

    def test_install_script_preserves_existing_default_config(self):
        prefix = self.root / "prefix"
        config_dir = prefix / "etc" / "omarchy-lexicon"
        config_dir.mkdir(parents=True)
        config_path = config_dir / "default.conf"
        config_path.write_text("KEEP_ME=1\n", encoding="utf-8")
        env = dict(self.env, PREFIX=str(prefix))
        subprocess.run([str(ROOT / "install.sh")], cwd=self.root, env=env, check=True, capture_output=True)
        self.assertEqual(config_path.read_text(encoding="utf-8"), "KEEP_ME=1\n")

    def test_pkgbuild_installs_self_contained_plugin_app(self):
        srcdir = self.root / "source"
        srcdir.mkdir()
        (srcdir / "omarchy-lexicon").symlink_to(ROOT, target_is_directory=True)
        pkgdir = self.root / "package"
        env = dict(self.env, srcdir=str(srcdir), pkgdir=str(pkgdir))
        subprocess.run(["bash", "-c", 'source "$1"; package', "bash", str(ROOT / "PKGBUILD")],
                       cwd=self.root, env=env, check=True, capture_output=True)
        self.assertFalse((pkgdir / "usr" / "bin" / "omarchy-lexicon").exists())
        plugin_dir = pkgdir / "usr" / "share" / "omarchy-lexicon" / "plugins" / "acme.lexicon"
        self.assertTrue((plugin_dir / "manifest.json").exists())
        self.assertTrue((plugin_dir / "LexiconOverlay.qml").exists())
        self.assertTrue((plugin_dir / "session.js").exists())
        self.assertTrue((plugin_dir / "i18n" / "en.json").exists())
        config = pkgdir / "etc" / "omarchy-lexicon" / "default.conf"
        payload = self.check_plugin_search(plugin_dir, ("--config", str(config), "--query", "app"))
        self.assertEqual(payload["results"], ["apple"])


if __name__ == "__main__":
    unittest.main()
