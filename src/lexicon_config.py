from __future__ import annotations

import os
from typing import Dict

DEFAULT_CONFIG_PATH = "/etc/omarchy-lexicon/default.conf"


def load_config(path: str | None) -> Dict[str, str]:
    if path is None:
        module_dir = os.path.dirname(os.path.abspath(__file__))
        prefix = os.path.dirname(os.path.dirname(module_dir))
        installed_path = os.path.join(prefix, "etc", "omarchy-lexicon", "default.conf")
        installed_layout = os.path.basename(module_dir) == "omarchy-lexicon" and os.path.basename(os.path.dirname(module_dir)) == "lib"
        if installed_layout and os.path.exists(installed_path):
            target_path = installed_path
        elif os.path.exists(DEFAULT_CONFIG_PATH):
            target_path = DEFAULT_CONFIG_PATH
        else:
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
