#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
MYAS_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
VERSION=$(<"${MYAS_ROOT}/VERSION")
OUT_DIR=${1:-"${MYAS_ROOT}/dist"}
YINSTALL_SOURCE=${YINSTALL_SOURCE:?set YINSTALL_SOURCE to the independent yinstall checkout}
ARCHIVE="${OUT_DIR}/myas-${VERSION}.tar.gz"
BUILD_DIR=$(mktemp -d)
trap 'rm -rf -- "${BUILD_DIR}"' EXIT
mkdir -p -- "${OUT_DIR}" "${BUILD_DIR}/myas-${VERSION}/yinstall"
tar -cf - -C "${MYAS_ROOT}" --exclude=.git --exclude=yinstall --exclude=tests --exclude=dist --exclude=logs . | tar -xf - -C "${BUILD_DIR}/myas-${VERSION}"
tar -cf - -C "${YINSTALL_SOURCE}" --exclude=.git --exclude=tests --exclude=dist --exclude=logs . | tar -xf - -C "${BUILD_DIR}/myas-${VERSION}/yinstall"
tar -czf "${ARCHIVE}" -C "${BUILD_DIR}" "myas-${VERSION}"
tar -xOzf "${ARCHIVE}" "myas-${VERSION}/lib/myas-common.sh" | grep -Fq '__MYAS_SYS_PASSWORD__' || { printf 'password placeholder missing\n' >&2; exit 1; }
printf '%s\n' "${ARCHIVE}"
