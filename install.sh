#!/usr/bin/env bash
set -euo pipefail

resolve_user_home() {
  if [ -n "${SUDO_USER:-}" ] && [ "$(id -u)" -eq 0 ]; then
    if command -v getent >/dev/null 2>&1; then
      local home_dir
      home_dir="$(getent passwd "${SUDO_USER}" 2>/dev/null | cut -d: -f6 || true)"
      if [ -n "${home_dir}" ] && [ -d "${home_dir}" ]; then
        printf '%s\n' "${home_dir}"
        return 0
      fi
    fi
    if [ -d "/home/${SUDO_USER}" ]; then
      printf '%s\n' "/home/${SUDO_USER}"
      return 0
    fi
  fi
  printf '%s\n' "${HOME:-$PWD}"
}

restore_sudo_user_ownership() {
  local target_path="${1:-}"
  if [ -z "${target_path}" ] || [ -z "${SUDO_USER:-}" ] || [ "${EUID:-$(id -u)}" -ne 0 ]; then
    return 0
  fi

  local owner="${SUDO_USER}"
  local group
  group="$(id -gn "${SUDO_USER}" 2>/dev/null || printf '%s' "${SUDO_USER}")"

  if [ -e "${target_path}" ]; then
    chown -R "${owner}:${group}" "${target_path}"
  fi

  local current="${target_path}"
  while [ "${current}" != "/" ] && [ "${current}" != "${USER_HOME}" ] && [ -n "${current}" ]; do
    if [ -d "${current}" ]; then
      chown "${owner}:${group}" "${current}"
    fi
    current="$(dirname "${current}")"
  done
}

if [ -z "${DESTDIR:-}" ] && [ "$(id -u)" -ne 0 ] && [ "${PREFIX:-/usr/local}" = "/usr/local" ] && [ ! -w "/usr/local" ]; then
  PREFIX="${HOME}/.local"
fi
PREFIX="${PREFIX:-/usr/local}"
USER_HOME="$(resolve_user_home)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${USER_HOME}/.config}"
if [ -n "${SUDO_USER:-}" ] && [ "$(id -u)" -eq 0 ]; then
  XDG_CONFIG_HOME="${USER_HOME}/.config"
fi

DESTDIR_PREFIX="${DESTDIR:-}"
CONFIG_DIR="${DESTDIR_PREFIX}${PREFIX}/etc/omarchy-lexicon"
DOC_DIR="${DESTDIR_PREFIX}${PREFIX}/share/doc/omarchy-lexicon"
SHARED_PLUGIN_DIR="${DESTDIR_PREFIX}${PREFIX}/share/omarchy-lexicon/plugins/acme.lexicon"
PLUGIN_TARGET_DIR="${PLUGIN_TARGET_DIR:-${XDG_CONFIG_HOME}/omarchy/plugins/acme.lexicon}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_plugin_tree() {
  local dest="${1}"
  install -d "${dest}" "${dest}/i18n"
  install -m644 "${ROOT_DIR}/plugins/acme.lexicon/manifest.json" "${dest}/manifest.json"
  install -m644 "${ROOT_DIR}/plugins/acme.lexicon/LexiconOverlay.qml" "${dest}/LexiconOverlay.qml"
  install -m755 "${ROOT_DIR}/plugins/acme.lexicon/search.py" "${dest}/search.py"
  install -m644 "${ROOT_DIR}/plugins/acme.lexicon/session.js" "${dest}/session.js"
  install -m644 "${ROOT_DIR}/plugins/acme.lexicon/i18n/en.json" "${dest}/i18n/en.json"
  for module in "${ROOT_DIR}"/src/*.py; do
    install -m644 "${module}" "${dest}/$(basename "${module}")"
  done
}

install -d "${CONFIG_DIR}" "${DOC_DIR}"
if [ ! -e "${CONFIG_DIR}/default.conf" ]; then
  install -m644 "${ROOT_DIR}/config/default.conf" "${CONFIG_DIR}/default.conf"
fi
install -m644 "${ROOT_DIR}/README.md" "${DOC_DIR}/README.md"

if [ -n "${DESTDIR:-}" ]; then
  install_plugin_tree "${SHARED_PLUGIN_DIR}"
else
  # Clean up any legacy standalone CLI binary or library dir from older installs.
  rm -f "${PREFIX}/bin/omarchy-lexicon" 2>/dev/null || true
  rm -rf "${PREFIX}/lib/omarchy-lexicon" 2>/dev/null || true

  install_plugin_tree "${PLUGIN_TARGET_DIR}"
  if [ -n "${SUDO_USER:-}" ] && [ "$(id -u)" -eq 0 ]; then
    restore_sudo_user_ownership "${PLUGIN_TARGET_DIR}"
  fi
fi

SHELL_JSON="${XDG_CONFIG_HOME}/omarchy/shell.json"
if [ -z "${DESTDIR:-}" ] && [ -f "${SHELL_JSON}" ]; then
  python3 -I -c "
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        config = json.load(f)
except Exception:
    sys.exit(0)
plugin_id = 'acme.lexicon'
plugins = config.get('plugins', [])
if not any(isinstance(p, dict) and p.get('id') == plugin_id for p in plugins):
    plugins.append({'id': plugin_id})
    config['plugins'] = plugins
    with open(path, 'w') as f:
        json.dump(config, f, indent=2)
        f.write('\n')
" "${SHELL_JSON}" 2>/dev/null || true
  if [ -n "${SUDO_USER:-}" ] && [ "$(id -u)" -eq 0 ]; then
    restore_sudo_user_ownership "${SHELL_JSON}"
  fi
fi

if [ ! -e /usr/share/dict/words ] && [ ! -e /usr/share/dict/words.txt ] && command -v pacman >/dev/null 2>&1; then
  printf 'Note: install the Arch package "words" to provide /usr/share/dict/words for the default wordlist.\n' >&2
  printf 'Example: sudo pacman -S --needed words\n' >&2
fi

if [ -z "${DESTDIR:-}" ] && [ -d "${USER_HOME}/.cache/quickshell" ]; then
  rm -f "${USER_HOME}/.cache/quickshell/qmlcache/adb27e0b608a0c7395dfb221242f7baa7b79a396.jsc" 2>/dev/null || true
  if command -v omarchy >/dev/null 2>&1; then
    omarchy restart shell >/dev/null 2>&1 || true
  elif command -v omarchy-shell >/dev/null 2>&1; then
    omarchy-shell shell rescanPlugins 2>/dev/null || true
  fi
fi

if [ -z "${DESTDIR:-}" ]; then
  printf 'Installed Omarchy plugin to %s\n' "${PLUGIN_TARGET_DIR}"
  printf 'Plugin registered in %s\n' "${SHELL_JSON}"
  printf 'To launch: omarchy-shell shell toggle acme.lexicon\n'
else
  printf 'Staged Omarchy plugin to %s\n' "${SHARED_PLUGIN_DIR}"
fi
