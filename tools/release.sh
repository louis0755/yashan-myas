#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
MYAS_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REPO_ROOT=$(cd -- "${MYAS_ROOT}/.." && pwd)
VERSION=${1:?usage: release.sh VERSION [DIST_DIR]}
[[ ${VERSION} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'invalid version\n' >&2; exit 1; }
DIST_DIR=${2:-"${REPO_ROOT}/dist"}
YINSTALL_SOURCE=${YINSTALL_SOURCE:?set YINSTALL_SOURCE to the independent yinstall checkout}
SECRET_FILE=${MYAS_RELEASE_SECRET_FILE:-"${REPO_ROOT}/.release/myas.env"}
[[ -f ${SECRET_FILE} && $(stat -c '%a' "${SECRET_FILE}") == 600 ]] || { printf 'release secret file must exist with mode 600\n' >&2; exit 1; }
# shellcheck disable=SC1090
source "${SECRET_FILE}"
[[ -n ${MYAS_DEFAULT_PASSWORD:-} ]] || { printf 'MYAS_DEFAULT_PASSWORD is required\n' >&2; exit 1; }
printf '%s\n' "${VERSION}" >"${MYAS_ROOT}/VERSION"
ARCHIVE=$(YINSTALL_SOURCE="${YINSTALL_SOURCE}" "${MYAS_ROOT}/tools/package.sh" "${DIST_DIR}")
sha256sum "${ARCHIVE}"
DEPLOY_DIR=$(mktemp -d)
trap 'rm -rf -- "${DEPLOY_DIR}"' EXIT
tar -xzf "${ARCHIVE}" -C "${DEPLOY_DIR}"
escaped_password=$(printf '%s' "${MYAS_DEFAULT_PASSWORD}" | sed 's/[&|\\]/\\&/g')
sed -i "s|__MYAS_SYS_PASSWORD__|${escaped_password}|g" "${DEPLOY_DIR}/myas-${VERSION}/lib/myas-common.sh"
DEPLOY_ARCHIVE="${DEPLOY_DIR}/myas-${VERSION}.tar.gz"
tar -czf "${DEPLOY_ARCHIVE}" -C "${DEPLOY_DIR}" "myas-${VERSION}"
scp -- "${DEPLOY_ARCHIVE}" "${PUBLISH_USER:-yashan}@${PUBLISH_HOST:-192.168.23.4}:${PUBLISH_DIR:-/tmp}/"
ssh "${PUBLISH_USER:-yashan}@${PUBLISH_HOST:-192.168.23.4}" bash -se -- "${VERSION}" "myas-${VERSION}.tar.gz" <<'REMOTE'
set -Eeuo pipefail
version=$1
archive=$2
root="${HOME}/.local/opt/myas"
tar -xzf "/tmp/${archive}" -C "${root}"
ln -sfn "${root}/myas-${version}" "${root}/current"
mkdir -p "${HOME}/.local/bin"
ln -sfn "${root}/current/myas.sh" "${HOME}/.local/bin/myas"
chmod +x "${root}/current/myas.sh" "${root}/current/yinstall/yinstall.sh"
export PATH="${HOME}/.local/bin:${PATH}"
unset -f myas 2>/dev/null || true
hash -r
myas config set YINSTALL_BIN "${root}/current/yinstall/yinstall.sh" >/dev/null
myas --version | grep -F "myas ${version}" >/dev/null
myas list >/dev/null
REMOTE
printf '%s\n' "published ${ARCHIVE}"
