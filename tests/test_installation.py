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
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith("LEXICON_") and key not in {"PYTHONPATH", "XDG_CONFIG_HOME"}}
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

    def test_install_script_installs_plugin_assets(self):
        prefix = self.root / "prefix"
        plugin_target = self.root / "plugin"
        env = dict(self.env, PREFIX=str(prefix), PLUGIN_TARGET_DIR=str(plugin_target), PATH=f"{prefix / 'bin'}:/usr/bin:/bin")
        subprocess.run([str(ROOT / "install.sh")], cwd=self.root, env=env, check=True, capture_output=True)

        manifest = plugin_target / "manifest.json"
        self.assertTrue(manifest.exists())
        self.assertTrue((plugin_target / "LexiconOverlay.qml").exists())
        self.assertTrue((plugin_target / "search.py").exists())
        self.assertTrue((plugin_target / "session.js").exists())

        result = subprocess.run([
            "python3",
            str(plugin_target / "search.py"),
            "--query",
            "app",
            "--limit",
            "5",
        ], cwd=self.root, env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertIn("results", payload)

    def test_install_script_defaults_to_user_local_prefix(self):
        home = self.root / "home"
        home.mkdir()
        env = dict(self.env, HOME=str(home), PREFIX=str(home / ".local"))
        subprocess.run([str(ROOT / "install.sh")], cwd=self.root, env=env, check=True, capture_output=True)

        self.assertTrue((home / ".local" / "bin" / "omarchy-lexicon").exists())
        self.assertTrue((home / ".config" / "omarchy" / "plugins" / "acme.lexicon" / "manifest.json").exists())

    def test_install_script_respects_xdg_config_home_and_destdir(self):
        home = self.root / "home"
        xdg = self.root / "xdg"
        env = dict(self.env, HOME=str(home), XDG_CONFIG_HOME=str(xdg), PREFIX="/usr/local")
        subprocess.run([str(ROOT / "install.sh")], cwd=self.root, env=env, check=True, capture_output=True)
        self.assertTrue((xdg / "omarchy" / "plugins" / "acme.lexicon" / "manifest.json").exists())

        destdir = self.root / "staging"
        env = dict(self.env, HOME=str(home), DESTDIR=str(destdir), PREFIX="/usr/local")
        subprocess.run([str(ROOT / "install.sh")], cwd=self.root, env=env, check=True, capture_output=True)
        self.assertTrue((destdir / "usr" / "local" / "bin" / "omarchy-lexicon").exists())
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
