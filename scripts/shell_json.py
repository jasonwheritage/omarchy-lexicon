#!/usr/bin/env python3
"""Add or remove the acme.lexicon entry in Omarchy's shell.json without damaging it.

- Changes nothing when the entry is already in the wanted state, or when the
  file can't be parsed or has an unexpected shape (it prints a warning instead).
- Keeps the file's indentation, trailing newline, permissions and owner.
- Writes atomically (temporary file in the same folder, then rename), so an
  interrupted write can't leave shell.json empty or half-written.
- Follows a symlinked shell.json (for example from a dotfiles manager) and
  updates the real file instead of replacing the link.
"""
from __future__ import annotations

import json
import os
import re
import sys
import tempfile

PLUGIN_ID = "acme.lexicon"


def detect_indent(text: str) -> int | str | None:
    match = re.search(r"^([ \t]+)\S", text, re.MULTILINE)
    if match:
        whitespace = match.group(1)
        return "\t" if whitespace.startswith("\t") else len(whitespace)
    return None if "\n" not in text.strip() else 2


def write_atomic(path: str, text: str) -> None:
    stat = os.stat(path)
    fd, temp_path = tempfile.mkstemp(prefix=".shell.json.", dir=os.path.dirname(path))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temp_path, stat.st_mode & 0o7777)
        try:
            os.chown(temp_path, stat.st_uid, stat.st_gid)
        except PermissionError:
            pass
        os.replace(temp_path, path)
    except BaseException:
        try:
            os.unlink(temp_path)
        except FileNotFoundError:
            pass
        raise


def update(path: str, action: str) -> str:
    """Return 'changed', 'unchanged' or 'skipped'."""
    path = os.path.realpath(path)
    try:
        with open(path, encoding="utf-8") as handle:
            original = handle.read()
        config = json.loads(original)
    except (OSError, ValueError):
        return "skipped"
    if not isinstance(config, dict):
        return "skipped"
    plugins = config.get("plugins", [])
    if not isinstance(plugins, list):
        return "skipped"

    def is_ours(entry: object) -> bool:
        return isinstance(entry, dict) and entry.get("id") == PLUGIN_ID

    if action == "add":
        if any(is_ours(entry) for entry in plugins):
            return "unchanged"
        updated = plugins + [{"id": PLUGIN_ID}]
    else:
        updated = [entry for entry in plugins if not is_ours(entry)]
        if len(updated) == len(plugins):
            return "unchanged"

    config["plugins"] = updated
    text = json.dumps(config, indent=detect_indent(original), ensure_ascii=False)
    if original.endswith("\n"):
        text += "\n"
    write_atomic(path, text)
    return "changed"


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[1] not in {"add", "remove"}:
        print("usage: shell_json.py add|remove PATH", file=sys.stderr)
        return 2
    action, path = argv[1], argv[2]
    result = update(path, action)
    if result == "skipped":
        verb = "add" if action == "add" else "remove"
        place = "to" if action == "add" else "from"
        print(
            f'Warning: left {path} unchanged because it could not be read as expected. '
            f'{verb.capitalize()} {{"id": "{PLUGIN_ID}"}} {place} its "plugins" list yourself.',
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
