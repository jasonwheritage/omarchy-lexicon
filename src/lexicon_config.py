from __future__ import annotations

import os
from typing import Dict

DEFAULT_CONFIG_PATH = "/etc/omarchy-lexicon/default.conf"


def _candidate_config_paths(module_dir: str) -> list[str]:
    home = os.environ.get("HOME") or os.path.expanduser("~")
    xdg_config = os.environ.get("XDG_CONFIG_HOME") or os.path.join(home, ".config")
    prefix = os.path.dirname(os.path.dirname(module_dir))
    return [
        os.path.join(module_dir, "default.conf"),
        os.path.join(xdg_config, "omarchy-lexicon", "default.conf"),
        os.path.join(home, ".local", "etc", "omarchy-lexicon", "default.conf"),
        os.path.join(prefix, "etc", "omarchy-lexicon", "default.conf"),
        DEFAULT_CONFIG_PATH,
    ]


def load_config(path: str | None) -> Dict[str, str]:
    if path is None:
        module_dir = os.path.dirname(os.path.abspath(__file__))
        target_path = next((candidate for candidate in _candidate_config_paths(module_dir) if os.path.exists(candidate)), None)
        if target_path is None:
            return {}
    else:
        target_path = path

    if not os.path.exists(target_path):
        raise FileNotFoundError(f"Config file not found: {target_path}")

    values: Dict[str, str] = {}
    with open(target_path, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                raise ValueError(f"Invalid config line: {line}")
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values
