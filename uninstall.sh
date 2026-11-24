#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [--purge]\n\n' "$(basename "$0")"
  printf 'Removes the omarchy-lexicon plugin. Your configuration and saved searches are kept.\n'
  printf '  --purge   also delete the configuration folder and saved searches\n'
}

PURGE=0
for arg in "$@"; do
  case "${arg}" in
    --purge) PURGE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

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
BIN_PATH="${DESTDIR_PREFIX}${PREFIX}/bin/omarchy-lexicon"
CONFIG_PATH="${DESTDIR_PREFIX}${PREFIX}/etc/omarchy-lexicon"
DOC_PATH="${DESTDIR_PREFIX}${PREFIX}/share/doc/omarchy-lexicon"
LIB_PATH="${DESTDIR_PREFIX}${PREFIX}/lib/omarchy-lexicon"
SHARED_PLUGIN_PATH="${DESTDIR_PREFIX}${PREFIX}/share/omarchy-lexicon"
PLUGIN_TARGET_DIR="${PLUGIN_TARGET_DIR:-${XDG_CONFIG_HOME}/omarchy/plugins/acme.lexicon}"
STATE_PATH="${XDG_STATE_HOME:-${USER_HOME}/.local/state}/omarchy-lexicon"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rm -f "${BIN_PATH}"
rm -rf "${DOC_PATH}"
rm -rf "${LIB_PATH}"
rm -rf "${SHARED_PLUGIN_PATH}"

SHELL_JSON="${XDG_CONFIG_HOME}/omarchy/shell.json"

if [ -z "${DESTDIR:-}" ]; then
  rm -rf "${PLUGIN_TARGET_DIR}"

  local_parent="${XDG_CONFIG_HOME}/omarchy/plugins"
  if [ -d "${local_parent}" ]; then
    rmdir --ignore-fail-on-non-empty "${local_parent}" 2>/dev/null || true
  fi

  omarchy_parent="${XDG_CONFIG_HOME}/omarchy"
  if [ -d "${omarchy_parent}" ]; then
    rmdir --ignore-fail-on-non-empty "${omarchy_parent}" 2>/dev/null || true
  fi

  if [ -f "${SHELL_JSON}" ]; then
    python3 -I "${ROOT_DIR}/scripts/shell_json.py" remove "${SHELL_JSON}" || true
  fi
fi

if [ "${PURGE}" -eq 1 ]; then
  rm -rf "${CONFIG_PATH}"
  if [ -z "${DESTDIR:-}" ]; then
    rm -rf "${STATE_PATH}"
  fi
  printf 'Deleted configuration in %s and saved searches in %s\n' "${CONFIG_PATH}" "${STATE_PATH}"
elif [ -e "${CONFIG_PATH}" ]; then
  printf 'Kept your configuration in %s (run with --purge to delete it)\n' "${CONFIG_PATH}"
fi

if [ -z "${DESTDIR:-}" ]; then
  printf 'Removed Omarchy plugin from %s\n' "${PLUGIN_TARGET_DIR}"
else
  printf 'Removed staged Omarchy plugin from %s\n' "${SHARED_PLUGIN_PATH}"
fi
