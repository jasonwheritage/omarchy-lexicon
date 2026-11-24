"""The plugin must not overwrite user configuration without explicit consent."""
import importlib.util
import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


shell_json = load_module("shell_json", ROOT / "scripts" / "shell_json.py")
lexicon_config = load_module("lexicon_config", ROOT / "src" / "lexicon_config.py")


class TempDirTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)


class ShellJsonTests(TempDirTest):
    def write(self, text: str) -> Path:
        path = self.root / "shell.json"
        path.write_text(text, encoding="utf-8")
        return path

    def test_add_keeps_indentation_other_entries_and_newline(self):
        path = self.write('{\n    "theme": "tokyo",\n    "plugins": [\n        {"id": "other.plugin"}\n    ]\n}\n')
        self.assertEqual(shell_json.update(str(path), "add"), "changed")
        text = path.read_text(encoding="utf-8")
        self.assertIn('\n    "theme": "tokyo",', text)
        self.assertTrue(text.endswith("}\n"))
        data = json.loads(text)
        self.assertEqual(data["plugins"], [{"id": "other.plugin"}, {"id": "acme.lexicon"}])

    def test_add_twice_and_remove_missing_leave_file_untouched(self):
        original = '{"plugins": [{"id": "acme.lexicon"}]}'
        path = self.write(original)
        self.assertEqual(shell_json.update(str(path), "add"), "unchanged")
        path_other = self.root / "other.json"
        path_other.write_text('{"plugins": []}', encoding="utf-8")
        self.assertEqual(shell_json.update(str(path_other), "remove"), "unchanged")
        self.assertEqual(path.read_text(encoding="utf-8"), original)
        self.assertEqual(path_other.read_text(encoding="utf-8"), '{"plugins": []}')

    def test_remove_only_drops_our_entry(self):
        path = self.write('{\n  "plugins": [\n    {"id": "acme.lexicon"},\n    {"id": "other.plugin"}\n  ]\n}\n')
        self.assertEqual(shell_json.update(str(path), "remove"), "changed")
        self.assertEqual(json.loads(path.read_text(encoding="utf-8"))["plugins"], [{"id": "other.plugin"}])

    def test_unparseable_or_unexpected_files_are_not_touched(self):
        for original in ('{"plugins": [ // comment\n]}', '[]', '{"plugins": "not a list"}'):
            path = self.write(original)
            self.assertEqual(shell_json.update(str(path), "add"), "skipped")
            self.assertEqual(path.read_text(encoding="utf-8"), original)

    def test_symlink_and_permissions_are_kept(self):
        real = self.root / "dotfiles" / "shell.json"
        real.parent.mkdir()
        real.write_text('{"plugins": []}\n', encoding="utf-8")
        real.chmod(0o600)
        link = self.root / "shell.json"
        link.symlink_to(real)
        self.assertEqual(shell_json.update(str(link), "add"), "changed")
        self.assertTrue(link.is_symlink())
        self.assertEqual(stat.S_IMODE(real.stat().st_mode), 0o600)
        self.assertEqual(json.loads(real.read_text(encoding="utf-8"))["plugins"], [{"id": "acme.lexicon"}])
        self.assertEqual([p.name for p in real.parent.iterdir()], ["shell.json"])


class ScriptTests(TempDirTest):
    def setUp(self):
        super().setUp()
        self.home = self.root / "home"
        (self.home / ".config" / "omarchy").mkdir(parents=True)
        self.shell_json = self.home / ".config" / "omarchy" / "shell.json"
        self.shell_json.write_text('{\n    "plugins": []\n}\n', encoding="utf-8")
        self.prefix = self.home / ".local"
        self.env = {k: v for k, v in os.environ.items() if k not in {"XDG_CONFIG_HOME", "XDG_STATE_HOME", "PYTHONPATH"}}
        self.env.update(HOME=str(self.home), PREFIX=str(self.prefix), PATH="/usr/bin:/bin", PYTHONDONTWRITEBYTECODE="1")

    def run_script(self, *args):
        return subprocess.run([str(ROOT / args[0]), *args[1:]], cwd=self.root, env=self.env,
                              check=True, capture_output=True, text=True)

    def test_install_registers_plugin_keeping_format(self):
        self.run_script("install.sh")
        text = self.shell_json.read_text(encoding="utf-8")
        self.assertIn('\n    "plugins": [', text)
        self.assertEqual(json.loads(text)["plugins"], [{"id": "acme.lexicon"}])

    def test_uninstall_keeps_config_and_saved_searches(self):
        self.run_script("install.sh")
        config = self.prefix / "etc" / "omarchy-lexicon" / "default.conf"
        config.write_text("SORT_MODE=length_desc\n", encoding="utf-8")
        state = self.home / ".local" / "state" / "omarchy-lexicon" / "overlay.json"
        state.parent.mkdir(parents=True)
        state.write_text("{}", encoding="utf-8")

        result = self.run_script("uninstall.sh")
        self.assertEqual(config.read_text(encoding="utf-8"), "SORT_MODE=length_desc\n")
        self.assertTrue(state.exists())
        self.assertIn("Kept your configuration", result.stdout)
        self.assertFalse((self.home / ".config" / "omarchy" / "plugins" / "acme.lexicon").exists())
        self.assertEqual(json.loads(self.shell_json.read_text(encoding="utf-8"))["plugins"], [])

    def test_uninstall_purge_deletes_config_and_saved_searches(self):
        self.run_script("install.sh")
        config_dir = self.prefix / "etc" / "omarchy-lexicon"
        state_dir = self.home / ".local" / "state" / "omarchy-lexicon"
        state_dir.mkdir(parents=True)
        self.run_script("uninstall.sh", "--purge")
        self.assertFalse(config_dir.exists())
        self.assertFalse(state_dir.exists())

    def test_uninstall_rejects_unknown_options(self):
        result = subprocess.run([str(ROOT / "uninstall.sh"), "--force"], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertTrue((self.home / ".config" / "omarchy" / "shell.json").exists())


class ConfigPrecedenceTests(TempDirTest):
    def test_user_config_wins_over_config_shipped_with_plugin(self):
        module_dir = self.root / "plugin"
        module_dir.mkdir()
        (module_dir / "default.conf").write_text("SORT_MODE=alpha\n", encoding="utf-8")
        user = self.root / "xdg" / "omarchy-lexicon" / "default.conf"
        user.parent.mkdir(parents=True)
        user.write_text("SORT_MODE=length_desc\n", encoding="utf-8")
        old = {k: os.environ.get(k) for k in ("HOME", "XDG_CONFIG_HOME")}
        os.environ.update(HOME=str(self.root), XDG_CONFIG_HOME=str(self.root / "xdg"))
        try:
            candidates = lexicon_config._candidate_config_paths(str(module_dir))
        finally:
            for key, value in old.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value
        first = next(c for c in candidates if os.path.exists(c))
        self.assertEqual(first, str(user))


class PackagingTests(unittest.TestCase):
    def test_pkgbuild_protects_system_config_on_upgrade(self):
        result = subprocess.run(["bash", "-c", 'source "$1"; printf "%s\\n" "${backup[@]}"', "bash", str(ROOT / "PKGBUILD")],
                                capture_output=True, text=True, check=True)
        self.assertIn("etc/omarchy-lexicon/default.conf", result.stdout.split())

    def test_release_bundle_ships_config_only_as_example(self):
        workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text(encoding="utf-8")
        self.assertIn('"$BUNDLE_DIR/default.conf.example"', workflow)
        self.assertNotIn('"$BUNDLE_DIR/default.conf"', workflow)


if __name__ == "__main__":
    unittest.main()
