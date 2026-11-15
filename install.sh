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
BIN_DIR="${DESTDIR_PREFIX}${PREFIX}/bin"
CONFIG_DIR="${DESTDIR_PREFIX}${PREFIX}/etc/omarchy-lexicon"
DOC_DIR="${DESTDIR_PREFIX}${PREFIX}/share/doc/omarchy-lexicon"
LIB_DIR="${DESTDIR_PREFIX}${PREFIX}/lib/omarchy-lexicon"
PLUGIN_TARGET_DIR="${PLUGIN_TARGET_DIR:-${XDG_CONFIG_HOME}/omarchy/plugins/acme.lexicon}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -d "${BIN_DIR}" "${CONFIG_DIR}" "${DOC_DIR}" "${LIB_DIR}"
install -m755 "${ROOT_DIR}/bin/omarchy-lexicon" "${BIN_DIR}/omarchy-lexicon"
install -m644 "${ROOT_DIR}"/src/*.py "${LIB_DIR}/"
if [ ! -e "${CONFIG_DIR}/default.conf" ]; then
  install -m644 "${ROOT_DIR}/config/default.conf" "${CONFIG_DIR}/default.conf"
fi
install -m644 "${ROOT_DIR}/README.md" "${DOC_DIR}/README.md"

if [ -z "${DESTDIR:-}" ]; then
  install -d "${PLUGIN_TARGET_DIR}"
  install -m644 "${ROOT_DIR}/plugins/acme.lexicon/manifest.json" "${PLUGIN_TARGET_DIR}/manifest.json"
  install -m644 "${ROOT_DIR}/plugins/acme.lexicon/LexiconOverlay.qml" "${PLUGIN_TARGET_DIR}/LexiconOverlay.qml"
  install -m755 "${ROOT_DIR}/plugins/acme.lexicon/search.py" "${PLUGIN_TARGET_DIR}/search.py"
  if [ -n "${SUDO_USER:-}" ] && [ "$(id -u)" -eq 0 ]; then
    restore_sudo_user_ownership "${PLUGIN_TARGET_DIR}"
  fi
fi

if [ ! -e /usr/share/dict/words ] && [ ! -e /usr/share/dict/words.txt ] && command -v pacman >/dev/null 2>&1; then
  printf 'Note: install the Arch package "words" to provide /usr/share/dict/words for the default wordlist.\n' >&2
  printf 'Example: sudo pacman -S --needed words\n' >&2
fi

printf 'Installed omarchy-lexicon to %s\n' "${PREFIX}"
if [ -z "${DESTDIR:-}" ]; then
  printf 'Installed Omarchy plugin to %s\n' "${PLUGIN_TARGET_DIR}"
fi
