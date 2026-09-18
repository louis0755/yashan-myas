#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
VERSION=${1:?usage: release.sh VERSION [DIST_DIR]}
[[ ${VERSION} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'invalid version: %s\n' "${VERSION}" >&2; exit 1; }
DIST_DIR=${2:-"${ROOT_DIR}/dist"}
PUBLISH_HOST=${PUBLISH_HOST:-192.168.23.4}
PUBLISH_USER=${PUBLISH_USER:-yashan}
PUBLISH_DIR=${PUBLISH_DIR:-/tmp}
SECRET_FILE=${MYAS_RELEASE_SECRET_FILE:-"${ROOT_DIR}/.release/myas.env"}
[[ -f ${SECRET_FILE} ]] || { printf 'release secret file not found: %s\n' "${SECRET_FILE}" >&2; exit 1; }
[[ $(stat -c '%a' "${SECRET_FILE}") == 600 ]] || { printf 'release secret file must have mode 600\n' >&2; exit 1; }
# shellcheck disable=SC1090
source "${SECRET_FILE}"
[[ -n ${MYAS_DEFAULT_PASSWORD:-} ]] || { printf 'MYAS_DEFAULT_PASSWORD is required\n' >&2; exit 1; }
printf '%s\n' "${VERSION}" >"${ROOT_DIR}/VERSION"
ARCHIVE=$("${ROOT_DIR}/tools/package.sh" "${DIST_DIR}")
CHECKSUM=$(sha256sum "${ARCHIVE}")
printf '%s\n' "${CHECKSUM}"
DEPLOY_DIR=$(mktemp -d)
trap 'rm -rf -- "${DEPLOY_DIR}"' EXIT
tar -xzf "${ARCHIVE}" -C "${DEPLOY_DIR}"
escaped_password=$(printf '%s' "${MYAS_DEFAULT_PASSWORD}" | sed 's/[&|\\]/\\&/g')
sed -i "s|__MYAS_SYS_PASSWORD__|${escaped_password}|g" "${DEPLOY_DIR}/myas-${VERSION}/lib/myas-common.sh"
DEPLOY_ARCHIVE="${DEPLOY_DIR}/$(basename -- "${ARCHIVE}")"
tar -czf "${DEPLOY_ARCHIVE}" -C "${DEPLOY_DIR}" "myas-${VERSION}"
scp -- "${DEPLOY_ARCHIVE}" "${PUBLISH_USER}@${PUBLISH_HOST}:${PUBLISH_DIR}/"
printf 'published %s to %s@%s:%s\n' "${ARCHIVE}" "${PUBLISH_USER}" "${PUBLISH_HOST}" "${PUBLISH_DIR}"
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${PUBLISH_USER}@${PUBLISH_HOST}" bash -se -- "${VERSION}" "$(basename -- "${ARCHIVE}")" <<'REMOTE'
set -Eeuo pipefail
version=$1
archive=$2
install_root="${HOME}/.local/opt/myas"
archive_path="/tmp/${archive}"
test -f "${archive_path}"
test -x "${HOME}/.local/bin/myas" || true
tar -xzf "${archive_path}" -C "${install_root}"
ln -sfn "${install_root}/myas-${version}" "${install_root}/current"
mkdir -p "${HOME}/.local/bin"
ln -sfn "${install_root}/current/myas.sh" "${HOME}/.local/bin/myas"
chmod +x "${install_root}/current/myas.sh" "${install_root}/current/yinstall/yinstall.sh"
export PATH="${HOME}/.local/bin:${PATH}"
unset -f myas 2>/dev/null || true
hash -r
myas config set YINSTALL_BIN "${install_root}/current/yinstall/yinstall.sh" >/dev/null
myas --version | grep -F "myas ${version}" >/dev/null
myas list >/dev/null
"${install_root}/current/yinstall/yinstall.sh" --help >/dev/null
config_dir="${HOME}/.myas"
instances_file="${config_dir}/instances.tsv"
if [[ -f ${instances_file} ]] && awk -F '\t' '$1 == "psftdb" { found=1 } END { exit !found }' "${instances_file}"; then
  cp "${instances_file}" "${instances_file}.bak"
  awk -F '\t' '$1 != "psftdb"' "${instances_file}" >"${instances_file}.tmp"
  mv "${instances_file}.tmp" "${instances_file}"
fi
myas create psftdb 23.4.14.105 --force
REMOTE
printf 'remote deployment and psftdb smoke test completed on %s@%s\n' "${PUBLISH_USER}" "${PUBLISH_HOST}"
