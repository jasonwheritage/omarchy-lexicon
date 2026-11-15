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
PLUGIN_TARGET_DIR="${PLUGIN_TARGET_DIR:-${XDG_CONFIG_HOME}/omarchy/plugins/acme.lexicon}"

rm -f "${BIN_PATH}"
rm -rf "${CONFIG_PATH}"
rm -rf "${DOC_PATH}"
rm -rf "${LIB_PATH}"

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
fi

printf 'Removed omarchy-lexicon installation from %s\n' "${PREFIX}"
if [ -z "${DESTDIR:-}" ]; then
  printf 'Removed Omarchy plugin from %s\n' "${PLUGIN_TARGET_DIR}"r
fi
