#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
VERSION=$(<"${ROOT_DIR}/VERSION")
OUT_DIR=${1:-"${ROOT_DIR}/dist"}
ARCHIVE="${OUT_DIR}/myas-${VERSION}.tar.gz"
# yinstall lives next to the myas checkout, not inside it.
YINSTALL_SOURCE=${YINSTALL_SOURCE:-"${ROOT_DIR}/../yinstall"}
[[ -f ${YINSTALL_SOURCE}/yinstall.sh ]] || { printf 'yinstall source not found: %s\n' "${YINSTALL_SOURCE}" >&2; exit 1; }
BUILD_DIR=$(mktemp -d)
trap 'rm -rf -- "${BUILD_DIR}"' EXIT
mkdir -p -- "${OUT_DIR}"
mkdir -p -- "${BUILD_DIR}/myas-${VERSION}/yinstall"
tar -cf - -C "${ROOT_DIR}" \
	--exclude=.git --exclude=yinstall --exclude=tests --exclude=dist --exclude=logs \
	--exclude=.release --exclude=legacy --exclude=docs --exclude='tools.bak.*' \
	. | tar -xf - -C "${BUILD_DIR}/myas-${VERSION}"
tar -cf - -C "${YINSTALL_SOURCE}" \
	--exclude=.git --exclude=tests --exclude=dist --exclude=logs \
	. | tar -xf - -C "${BUILD_DIR}/myas-${VERSION}/yinstall"
tar -czf "${ARCHIVE}" -C "${BUILD_DIR}" "myas-${VERSION}"
# Do not pipe into "grep -q": with pipefail a SIGPIPE from the extractor turns a
# successful match into a false failure. Extract first, then search.
tar -xOzf "${ARCHIVE}" "myas-${VERSION}/lib/myas-common.sh" >"${BUILD_DIR}/placeholder-check"
if grep -Fq '__MYAS_SYS_PASSWORD__' "${BUILD_DIR}/placeholder-check"; then :; else
	printf 'package is missing the password placeholder\n' >&2
	exit 1
fi
printf '%s\n' "${ARCHIVE}"
