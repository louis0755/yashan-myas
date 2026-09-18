#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
ARCHIVE=${1:?usage: upgrade.sh ARCHIVE [INSTALL_ROOT]}
INSTALL_ROOT=${2:-"${HOME}/.local/opt/myas"}
[[ -f ${ARCHIVE} ]] || { printf 'archive not found: %s\n' "${ARCHIVE}" >&2; exit 1; }
ROOT_NAME=$(tar -tzf "${ARCHIVE}" | sed -n '1s,/.*,,p')
VERSION=$(tar -xOzf "${ARCHIVE}" "${ROOT_NAME}/VERSION")
[[ ${VERSION} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'invalid package version\n' >&2; exit 1; }
mkdir -p -- "${INSTALL_ROOT}"
tar -xzf "${ARCHIVE}" -C "${INSTALL_ROOT}"
ln -sfn -- "${INSTALL_ROOT}/${ROOT_NAME}" "${INSTALL_ROOT}/current"
mkdir -p -- "${HOME}/.local/bin"
ln -sfn -- "${INSTALL_ROOT}/current/myas.sh" "${HOME}/.local/bin/myas"
chmod +x -- "${INSTALL_ROOT}/current/myas.sh" "${INSTALL_ROOT}/current/yinstall/yinstall.sh"
printf 'upgraded to myas %s\n' "${VERSION}"
