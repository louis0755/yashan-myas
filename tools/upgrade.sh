#!/usr/bin/env bash
set -Eeuo pipefail
ARCHIVE=${1:?usage: upgrade.sh ARCHIVE [INSTALL_ROOT]}
INSTALL_ROOT=${2:-"${HOME}/.local/opt/myas"}
ROOT_NAME=$(tar -tzf "${ARCHIVE}" | sed -n '1s,/.*,,p')
mkdir -p -- "${INSTALL_ROOT}" "${HOME}/.local/bin"
tar -xzf "${ARCHIVE}" -C "${INSTALL_ROOT}"
ln -sfn -- "${INSTALL_ROOT}/${ROOT_NAME}" "${INSTALL_ROOT}/current"
ln -sfn -- "${INSTALL_ROOT}/current/myas.sh" "${HOME}/.local/bin/myas"
printf 'upgraded to %s\n' "${ROOT_NAME}"
