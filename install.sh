#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="${PREFIX}/bin"
CONFIG_DIR="${PREFIX}/etc/omarchy-lexicon"
DOC_DIR="${PREFIX}/share/doc/omarchy-lexicon"
LIB_DIR="${PREFIX}/lib/omarchy-lexicon"
KEYBIND_TARGET_DIR="${KEYBIND_TARGET_DIR:-${HOME}/.config/hypr/conf.d}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -d "${BIN_DIR}" "${CONFIG_DIR}" "${DOC_DIR}" "${LIB_DIR}"
install -m755 "${ROOT_DIR}/bin/omarchy-lexicon" "${BIN_DIR}/omarchy-lexicon"
install -m755 "${ROOT_DIR}/bin/omarchy-lexicon-walker" "${BIN_DIR}/omarchy-lexicon-walker"
install -m644 "${ROOT_DIR}"/src/*.py "${LIB_DIR}/"
install -m644 "${ROOT_DIR}/config/default.conf" "${CONFIG_DIR}/default.conf"
install -m644 "${ROOT_DIR}/config/keybinds.conf" "${CONFIG_DIR}/keybinds.conf"
install -m644 "${ROOT_DIR}/README.md" "${DOC_DIR}/README.md"

if [ ! -e /usr/share/dict/words ] && [ ! -e /usr/share/dict/words.txt ] && command -v pacman >/dev/null 2>&1; then
  printf 'Note: install the Arch package "words" to provide /usr/share/dict/words for the default wordlist.\n' >&2
  printf 'Example: sudo pacman -S --needed words\n' >&2
fi

if [ -d "${KEYBIND_TARGET_DIR}" ]; then
  install -m644 "${ROOT_DIR}/config/keybinds.conf" "${KEYBIND_TARGET_DIR}/omarchy-lexicon.conf"
fi

printf 'Installed omarchy-lexicon to %s\n' "${PREFIX}"
