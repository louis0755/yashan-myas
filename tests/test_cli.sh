#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf -- "${TMP_DIR}"' EXIT
CONFIG_DIR="${TMP_DIR}/config"
PACKAGE_DIR="${TMP_DIR}/packages"
MARKER="${TMP_DIR}/marker"
FAKE_YINSTALL="${TMP_DIR}/yinstall.sh"
FAKE_PS="${TMP_DIR}/ps"
PATH_BIN="${TMP_DIR}/path-bin"
LOCAL_CHECK_BIN="${TMP_DIR}/local-check-bin"
PATH_CONFIG_DIR="${TMP_DIR}/path-config"
BUNDLED_CONFIG_DIR="${TMP_DIR}/bundled-config"
YINSTALL_CONFIG_DIR="${CONFIG_DIR}/yinstall"
mkdir -p -- "${PACKAGE_DIR}" "${LOCAL_CHECK_BIN}"
touch "${PACKAGE_DIR}/yashandb-23.4.14.100-linux-x86_64.tar.gz"
touch "${PACKAGE_DIR}/yashandb-23.5.6.100-linux-x86_64.tar.gz"
touch "${PACKAGE_DIR}/yashandb-27.1.1.2-356-gd953d3665a9-linux-x86_64.tar.gz"

printf '%s\n' \
	'#!/usr/bin/env bash' \
	'set -Eeuo pipefail' \
	'printf "yinstall:%s\n" "$*" >>"${MYAS_TEST_MARKER}"' \
	'printf "syspwd=%s\n" "${YINSTALL_SYS_PASSWORD:-}" >>"${MYAS_TEST_MARKER}"' \
	'stage_dir=""' \
	'while (($#)); do' \
	'  case "$1" in' \
	'  --stage-dir) stage_dir=$2; shift 2 ;;' \
	'  *) shift ;;' \
	'  esac' \
	'done' \
	'[[ -n ${stage_dir} ]]' \
	'[[ ${MYAS_TEST_FAIL:-false} != true ]] || exit 1' \
	'mkdir -p -- "${stage_dir}/bin"' \
	'touch "${stage_dir}/hosts.toml"' \
	'printf "%s\n" "#!/usr/bin/env bash" "printf '\''yasboot:%s\\n'\'' \"\$*\" >>\"\${MYAS_TEST_MARKER}\"" >"${stage_dir}/bin/yasboot"' \
	'chmod +x "${stage_dir}/bin/yasboot"' >"${FAKE_YINSTALL}"
chmod +x "${FAKE_YINSTALL}"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${FAKE_PS}"
chmod +x "${FAKE_PS}"
printf '%s\n' '#!/usr/bin/env bash' 'exit 99' >"${LOCAL_CHECK_BIN}/ssh"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${LOCAL_CHECK_BIN}/sudo"
chmod +x "${LOCAL_CHECK_BIN}/ssh" "${LOCAL_CHECK_BIN}/sudo"
mkdir -p -- "${YINSTALL_CONFIG_DIR}" "${PATH_BIN}"
cp -- "${FAKE_YINSTALL}" "${YINSTALL_CONFIG_DIR}/yinstall.sh"
cp -- "${FAKE_YINSTALL}" "${PATH_BIN}/yinstall"
chmod +x "${YINSTALL_CONFIG_DIR}/yinstall.sh" "${PATH_BIN}/yinstall"

run_myas() {
	env MYAS_CONFIG_DIR="${CONFIG_DIR}" MYAS_TEST_MARKER="${MARKER}" "${ROOT_DIR}/myas.sh" "$@"
}

ln -s -- "${ROOT_DIR}/myas.sh" "${TMP_DIR}/myas-link"
env MYAS_CONFIG_DIR="${TMP_DIR}/link-config" "${TMP_DIR}/myas-link" --version | grep -F "myas $(<"${ROOT_DIR}/VERSION")" >/dev/null

assert_failure() {
	if "$@" >"${TMP_DIR}/stdout" 2>"${TMP_DIR}/stderr"; then
		echo "expected command to fail: $*" >&2
		return 1
	fi
}

assert_contains() {
	local text=$1 file=$2
	grep -F -- "${text}" "${file}" >/dev/null
}

run_myas --version | grep -F "myas $(<"${ROOT_DIR}/VERSION")" >/dev/null
run_myas --help >"${TMP_DIR}/help"
grep -F "myas $(<"${ROOT_DIR}/VERSION")" "${TMP_DIR}/help" >/dev/null
assert_contains 'delete NAME_OR_CLUSTER' "${TMP_DIR}/help"
run_myas config show | grep -F 'YINSTALL_BIN=' >/dev/null
env MYAS_CONFIG_DIR="${PATH_CONFIG_DIR}" MYAS_TEST_MARKER="${MARKER}" PATH="${PATH_BIN}:${PATH}" \
	"${ROOT_DIR}/myas.sh" config show | grep -F "YINSTALL_BIN=${PATH_BIN}/yinstall" >/dev/null
env MYAS_CONFIG_DIR="${BUNDLED_CONFIG_DIR}" MYAS_TEST_MARKER="${MARKER}" \
		"${ROOT_DIR}/myas.sh" config show | grep -F 'YINSTALL_BIN=' >/dev/null
printf '%s\n' 'MEMORY_LIMIT=50' >>"${CONFIG_DIR}/settings.conf"
if run_myas config show | grep -F 'MEMORY_LIMIT=' >/dev/null; then
	echo 'deprecated MEMORY_LIMIT is still visible' >&2
	exit 1
fi
if grep -F 'MEMORY_LIMIT=' "${CONFIG_DIR}/settings.conf" >/dev/null; then
	echo 'deprecated MEMORY_LIMIT was not removed from settings' >&2
	exit 1
fi
assert_failure run_myas config set MEMORY_LIMIT 50
assert_failure run_myas create invalidrecommend 23.4.14.100 --recommend-memory
run_myas config set SYS_PASSWORD TestInitial-2026 >/dev/null
run_myas config set BASE_DIR "${TMP_DIR}/instances" >/dev/null
run_myas config set PACKAGE_DIR "${PACKAGE_DIR}" >/dev/null
run_myas config set YINSTALL_BIN "${FAKE_YINSTALL}" >/dev/null
run_myas config set BASE_DIR "${TMP_DIR}" >/dev/null
run_myas config set OS_USER "$(id -un)" >/dev/null
run_myas config set OS_GROUP "$(id -gn)" >/dev/null
run_myas config show | grep -F 'SSH_USER=yashan' >/dev/null
run_myas config show | grep -F 'YASOM_PORT_START=1701' >/dev/null
run_myas config show | grep -F 'MYSQL_PORT_START=3307' >/dev/null
run_myas config show | grep -F 'SYS_PASSWORD=********' >/dev/null
[[ $(stat -c '%a' "${CONFIG_DIR}/settings.conf") == 600 ]]
assert_failure run_myas check 'bad host'
env PATH="${LOCAL_CHECK_BIN}:${PATH}" MYAS_CONFIG_DIR="${CONFIG_DIR}" "${ROOT_DIR}/myas.sh" check --local >/dev/null
run_myas config set BASE_DIR "${TMP_DIR}/instances" >/dev/null
run_myas create appdb 23.4.14.100 --target 10.0.0.11 --db-port 1703
run_myas config set YASOM_PORT_START 1801 >/dev/null
run_myas config set SYS_PASSWORD LocalPass-2026 >/dev/null
run_myas create localdb 23.4.14.100
run_myas create nextdb 23.4.14.100
run_myas create forcedb 23.4.14.100 --db-port 1811 --force --memory-size 1G
assert_contains '--force' "${MARKER}"
assert_contains '--memory-size 1G' "${MARKER}"
run_myas create mysqldb 23.4.14.100 --db-port 1815 --mysql-port 3310
assert_contains '--mode mysql --mysql-port 3310' "${MARKER}"
run_myas create planneddb 23.4.14.100 --db-port 1819 --dry-run >"${TMP_DIR}/dry-run-output"
assert_contains 'no instance registration was kept' "${TMP_DIR}/dry-run-output"
run_myas create nativedb 23.4.14.100 --db-port 1823 --use-native-type
assert_contains '--use-native-type' "${MARKER}"
run_myas create gbkdb 23.4.14.100 --db-port 1827 --character-set gbk
assert_contains '--character-set GBK' "${MARKER}"
run_myas create customdb 27.1.1.2-356-gd953d3665a9 --db-port 1867 --remarks custom-build
run_myas create hadb 23.4.14.100 --target 10.0.0.11 --db-port 1835 --host-ip 10.0.0.11 --standbys 10.0.0.12
assert_contains '--standbys 10.0.0.12' "${MARKER}"
run_myas create test-23414100 23.4.14.100 --db-port 1843
printf '%s\n' \
	$'legacy-test\t23.4.7.113\tys1847\t1847\t1845\t1846\t1848\tlocal\t/tmp/home\t/tmp/data\t/tmp/log\t/tmp/stage\t/tmp/package\tINSTALLED\ttest-2347113\t__MYAS_EMPTY__' \
	>>"${CONFIG_DIR}/instances.tsv"
run_myas list >"${TMP_DIR}/dotted-version-remarks-list"
grep -E 'ys1843.*test-23\.4\.14\.100' "${TMP_DIR}/dotted-version-remarks-list" >/dev/null
grep -E 'ys1847.*test-2347113' "${TMP_DIR}/dotted-version-remarks-list" >/dev/null
run_myas create test-2356100 23.5.6.100 --db-port 1851 --remarks custom-remarks
run_myas list >"${TMP_DIR}/custom-remarks-list"
grep -E 'ys1851.*custom-remarks' "${TMP_DIR}/custom-remarks-list" >/dev/null
# Internal builds carry a build suffix; the suffix must survive verbatim so that
# YASDB_HOME/<version>, the default package name, and the remarks all agree.
run_myas create test-27112-356-gd953d3665a9 27.1.1.2-356-gd953d3665a9 --db-port 1859
run_myas list >"${TMP_DIR}/build-suffix-list"
grep -E 'ys1859.*test-27\.1\.1\.2-356-gd953d3665a9' "${TMP_DIR}/build-suffix-list" >/dev/null
assert_contains '--package '"${PACKAGE_DIR}"'/yashandb-27.1.1.2-356-gd953d3665a9-linux-x86_64.tar.gz' "${MARKER}"
# The full version also has to reach yinstall, which places the software under it.
assert_contains '--db-version 27.1.1.2-356-gd953d3665a9' "${MARKER}"
assert_contains '--db-version 23.4.14.100' "${MARKER}"
assert_failure run_myas create baddb 27.1.1.2- --db-port 1863
assert_failure run_myas create baddb 27.1.1.2-356- --db-port 1863
assert_failure run_myas create baddb 27.1.1.2-356-gd953d3665a9. --db-port 1863
assert_failure run_myas create baddb 27.1.1.2-356_gd953d3665a9 --db-port 1863
assert_failure run_myas create baddb ../27.1.1.2 --db-port 1863
assert_failure run_myas create baddb 27.1.1.2/../../etc --db-port 1863

# --legacy selects the 22.2-era install flow: the flag reaches yinstall and the
# registration records it, while the combinations that flow cannot honor fail early.
touch "${PACKAGE_DIR}/yashandb-22.2.12.100-linux-x86_64.tar.gz"
run_myas create legacy22db 22.2.12.100 --db-port 1871 --legacy
assert_contains '--legacy' "${MARKER}"
grep -F $'\tlegacy' "${CONFIG_DIR}/instances.tsv" >/dev/null
assert_failure run_myas create legacyha 22.2.12.100 --target 10.0.0.11 --db-port 1875 --host-ip 10.0.0.11 --standbys 10.0.0.12 --legacy
assert_failure run_myas create legacymysql 22.2.12.100 --db-port 1879 --mysql-port 3314 --legacy
assert_failure run_myas create legacymem 22.2.12.100 --db-port 1883 --memory-size 1G --legacy
assert_failure run_myas create legacynative 22.2.12.100 --db-port 1887 --use-native-type --legacy
assert_failure run_myas create legacycharset 22.2.12.100 --db-port 1891 --character-set GB18030 --legacy
run_myas info legacy22db >"${TMP_DIR}/legacy-info"
assert_contains 'Install mode:  legacy' "${TMP_DIR}/legacy-info"
# Legacy yasboot installs under <install-path>/yashandb/<version>, so env discovers it.
mkdir -p -- "${TMP_DIR}/instances/ys1871/yasdb-home/yashandb/22.2.12.100/bin"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${TMP_DIR}/instances/ys1871/yasdb-home/yashandb/22.2.12.100/bin/yasdb"
chmod +x "${TMP_DIR}/instances/ys1871/yasdb-home/yashandb/22.2.12.100/bin/yasdb"
mkdir -p -- "${TMP_DIR}/instances/ys1871/yasdb-home/yashandb/22.2.12.100/log"
run_myas env ys1871 >"${TMP_DIR}/legacy-environment"
assert_contains "YASDB_HOME=${TMP_DIR}/instances/ys1871/yasdb-home/yashandb/22.2.12.100" "${TMP_DIR}/legacy-environment"
# Legacy yasboot ignores --log-path, so env must report the directory it really uses.
assert_contains "YASHANDB_LOG=${TMP_DIR}/instances/ys1871/yasdb-home/yashandb/22.2.12.100/log" "${TMP_DIR}/legacy-environment"
if grep -F "YASHANDB_LOG=${TMP_DIR}/instances/ys1871/yasdb-log" "${TMP_DIR}/legacy-environment" >/dev/null; then
	echo 'legacy env reported the unused --log-path' >&2
	exit 1
fi
run_myas info ys1871 >"${TMP_DIR}/legacy-info-log"
assert_contains "Log path:      ${TMP_DIR}/instances/ys1871/yasdb-home/yashandb/22.2.12.100/log" "${TMP_DIR}/legacy-info-log"

# Instances registered before the character set was recorded keep the effective
# value in the generated cluster configuration; the list falls back to reading it.
printf '%s\n' '[group.config]' '    CHARACTER_SET = "utf8"' >"${TMP_DIR}/instances/ys1703/install/ys1703.toml"
run_myas >"${TMP_DIR}/list"
assert_contains 'PORT' "${TMP_DIR}/list"
assert_contains 'ys1703' "${TMP_DIR}/list"
assert_contains 'appdb' "${TMP_DIR}/list"
assert_contains 'Yes (3310)' "${TMP_DIR}/list"
grep -E 'ys1703.*INSTALLED' "${TMP_DIR}/list" >/dev/null
# The current instance is marked in the first column, and CHARSET follows PORT.
grep -E '^CUR +NAME +VERSION +PORT +CHARSET +MYSQL +STATUS +REMARKS$' "${TMP_DIR}/list" >/dev/null
grep -E 'ys1703 +23\.4\.14\.100 +1703 +UTF8' "${TMP_DIR}/list" >/dev/null
grep -E 'ys1827 +23\.4\.14\.100 +1827 +GBK' "${TMP_DIR}/list" >/dev/null
# Internal builds keep only the release version and build number in VERSION; the
# full version stays readable through REMARKS.
grep -E 'ys1859 +27\.1\.1\.2-356 +1859 +- +No +INSTALLED +test-27\.1\.1\.2-356-gd953d3665a9$' "${TMP_DIR}/list" >/dev/null
grep -E 'ys1867 +27\.1\.1\.2-356 +1867 +- +No +INSTALLED +custom-build 27\.1\.1\.2-356-gd953d3665a9$' "${TMP_DIR}/list" >/dev/null
if grep -E 'ys1859 +27\.1\.1\.2-356-gd953d3665a9' "${TMP_DIR}/list" >/dev/null; then
	echo 'the VERSION column must not repeat the build suffix' >&2
	exit 1
fi
if grep -F 'ys1819' "${TMP_DIR}/list" >/dev/null; then
	echo 'dry-run left an instance registration behind' >&2
	exit 1
fi

printf '%s\n' '#!/usr/bin/env bash' \
	"printf '%s\\n' '${TMP_DIR}/instances/ys1703/yasdb-home/23.4.14.100/bin/yasdb nomount -D ${TMP_DIR}/instances/ys1703/yasdb-data/db-1-1'" >"${FAKE_PS}"
env MYAS_CONFIG_DIR="${CONFIG_DIR}" MYAS_TEST_MARKER="${MARKER}" MYAS_PS_BIN="${FAKE_PS}" YASHANDB_CLUSTER=ys1703 \
	"${ROOT_DIR}/myas.sh" list >"${TMP_DIR}/running-list"
grep -E '^\[\*\] +ys1703 .*RUNNING' "${TMP_DIR}/running-list" >/dev/null
if grep -E '^ +ys1703 .*RUNNING' "${TMP_DIR}/running-list" >/dev/null; then
	echo 'the current instance must be marked in the CUR column' >&2
	exit 1
fi
assert_contains $'appdb\t23.4.14.100\tys1703\t1703\t1701\t1702\t1704' "${CONFIG_DIR}/instances.tsv"
assert_contains $'localdb\t23.4.14.100\tys1803\t1803\t1801\t1802\t1804\tlocal' "${CONFIG_DIR}/instances.tsv"
assert_contains $'nextdb\t23.4.14.100\tys1807\t1807\t1805\t1806\t1808\tlocal' "${CONFIG_DIR}/instances.tsv"
assert_contains $'mysqldb\t23.4.14.100\tys1815\t1815\t1813\t1814\t1816\tlocal' "${CONFIG_DIR}/instances.tsv"
grep -F $'\tINSTALLED\t__MYAS_EMPTY__\t3310\t__MYAS_EMPTY__' "${CONFIG_DIR}/instances.tsv" >/dev/null
grep -F $'\tINSTALLED\t__MYAS_EMPTY__\t__MYAS_EMPTY__\tGBK' "${CONFIG_DIR}/instances.tsv" >/dev/null
# A non-legacy create keeps the legacy column empty, so the row ends with four placeholders.
grep -F $'\tINSTALLED\t__MYAS_EMPTY__\t__MYAS_EMPTY__\t__MYAS_EMPTY__\t__MYAS_EMPTY__' "${CONFIG_DIR}/instances.tsv" >/dev/null
assert_contains $'\tINSTALLED\t' "${CONFIG_DIR}/instances.tsv"
assert_contains 'db install --package' "${MARKER}"
assert_contains '--local' "${MARKER}"
assert_contains 'syspwd=TestInitial-2026' "${MARKER}"
assert_contains 'syspwd=LocalPass-2026' "${MARKER}"
if grep -F -- '--db-admin-password' "${MARKER}" >/dev/null; then
	echo 'database password passed on the command line' >&2
	exit 1
fi
run_myas env ys1703 >"${TMP_DIR}/environment"
assert_contains 'export YASHANDB_CLUSTER=ys1703' "${TMP_DIR}/environment"
run_myas env ys1815 | grep -F 'export YASHANDB_MYSQL_PORT=3310' >/dev/null
assert_contains "export YASHANDB_HOME=${TMP_DIR}/instances/ys1703/yasdb-home" "${TMP_DIR}/environment"
env MYAS_CONFIG_DIR="${CONFIG_DIR}" MYAS_TEST_MARKER="${MARKER}" bash -c '
  source <("$1" env ys1703)
  [[ ${YASHANDB_CLUSTER} == ys1703 ]]
  [[ ${YASHANDB_PORT} == 1703 ]]
  [[ ${YASDB_HOME} == "$2/instances/ys1703/yasdb-home/23.4.14.100" ]]
  [[ ${YASDB_DATA} == "$2/instances/ys1703/yasdb-data/db-1-1" ]]
' _ "${ROOT_DIR}/myas.sh" "${TMP_DIR}"
mkdir -p -- "${TMP_DIR}/home/.yasboot/ys1703_yasdb_home/conf"
printf '%s\n' 'export YASDB_HOME=/generated/home' 'export YASDB_DATA=/generated/data' >"${TMP_DIR}/home/.yasboot/ys1703_yasdb_home/conf/ys1703.bashrc"
env HOME="${TMP_DIR}/home" MYAS_CONFIG_DIR="${CONFIG_DIR}" MYAS_TEST_MARKER="${MARKER}" bash -c '
  source <("$1" env ys1703)
  [[ ${YASDB_HOME} == /generated/home ]]
  [[ ${YASDB_DATA} == /generated/data ]]
' _ "${ROOT_DIR}/myas.sh"
run_myas alias >"${TMP_DIR}/aliases"
assert_contains "alias ys1703='source <(${ROOT_DIR}/myas.sh env ys1703)'" "${TMP_DIR}/aliases"
env MYAS_CONFIG_DIR="${CONFIG_DIR}" MYAS_TEST_MARKER="${MARKER}" MYAS_PS_BIN="${FAKE_PS}" bash -c '
  shopt -s expand_aliases
  eval "$("$1" shell-init)"
  type myas >/dev/null
  myas create autorefresh 23.4.14.100 --db-port 1831 >/dev/null
  type ys1831 >/dev/null
  type ys1703 >/dev/null
  ys1703 >"$2"
  [[ ${YASHANDB_CLUSTER} == ys1703 ]]
  grep -F "YashanDB '\''ys1703'\'' (version 23.4.14.100) is now active" "$2" >/dev/null
  grep -F "Status: RUNNING" "$2" >/dev/null
  grep -F "MySQL mode: No" "$2" >/dev/null
  ys1815 >"$3"
  grep -F "Status: INSTALLED" "$3" >/dev/null
  grep -F "MySQL mode: Yes (port 3310)" "$3" >/dev/null
' _ "${ROOT_DIR}/myas.sh" "${TMP_DIR}/activation-output" "${TMP_DIR}/mysql-activation-output"

run_myas shutdown ys1703
run_myas start ys1703
run_myas restart ys1703
assert_contains 'yasboot:cluster stop -c ys1703' "${MARKER}"
assert_contains 'yasboot:process yasagent stop -c ys1703 -t' "${MARKER}"
assert_contains 'yasboot:process yasom start -c ys1703 -t' "${MARKER}"
assert_contains 'yasboot:cluster restart -c ys1703' "${MARKER}"

# MYAS-023: a successful --precheck must not block the real create of the same name.
run_myas create precheckdb 23.4.14.100 --db-port 1839 --precheck >"${TMP_DIR}/precheck-output"
assert_contains 'no instance registration was kept' "${TMP_DIR}/precheck-output"
if grep -F $'precheckdb\t' "${CONFIG_DIR}/instances.tsv" >/dev/null; then
	echo 'precheck left an instance registration behind' >&2
	exit 1
fi
run_myas create precheckdb 23.4.14.100 --db-port 1839
assert_contains $'precheckdb\t23.4.14.100\tys1839\t1839\t1837\t1838\t1840\tlocal' "${CONFIG_DIR}/instances.tsv"
grep -F $'\tINSTALLED\t' "${CONFIG_DIR}/instances.tsv" >/dev/null

assert_failure env MYAS_CONFIG_DIR="${CONFIG_DIR}" MYAS_TEST_MARKER="${MARKER}" MYAS_TEST_FAIL=true "${ROOT_DIR}/myas.sh" \
	create failed 23.4.14.100 --target 10.0.0.11 --db-port 1903
assert_contains $'failed\t23.4.14.100\tys1903\t1903\t1901\t1902\t1904' "${CONFIG_DIR}/instances.tsv"
assert_contains $'\tREGISTERED_FAILED\t' "${CONFIG_DIR}/instances.tsv"
run_myas info ys1903 | grep -F 'Lifecycle:     REGISTERED_FAILED' >/dev/null
run_myas list >"${TMP_DIR}/failed-list"
grep -E 'ys1903.*FAIL' "${TMP_DIR}/failed-list" >/dev/null

# MYAS-022: legacy FAILED registration without yasboot must be deletable in one command.
FAKE_SUDO="${TMP_DIR}/sudo"
FAKE_DELETE_PS="${TMP_DIR}/delete-ps"
printf '%s\n' '#!/usr/bin/env bash' '[[ ${1:-} == -n ]] && shift' 'exec "$@"' >"${FAKE_SUDO}"
printf '%s\n' '#!/usr/bin/env bash' \
	"printf '%s\\n' '424242 ${TMP_DIR}/instances/ys1907/yasdb-home/23.4.14.100/bin/yasom --init -c ys1907 -l 127.0.0.1:1905 -d'" >"${FAKE_DELETE_PS}"
chmod +x "${FAKE_SUDO}" "${FAKE_DELETE_PS}"
mkdir -p -- "${TMP_DIR}/instances/ys1907/yasdb-data" "${TMP_DIR}/instances/ys1907/yasdb-log" "${TMP_DIR}/instances/ys1907/install"
printf '%s\n' \
	$'legacydb\t23.4.14.100\tys1907\t1907\t1905\t1906\t1908\tlocal'$'\t'"${TMP_DIR}/instances/ys1907/yasdb-home"$'\t'"${TMP_DIR}/instances/ys1907/yasdb-data"$'\t'"${TMP_DIR}/instances/ys1907/yasdb-log"$'\t'"${TMP_DIR}/instances/ys1907/install"$'\t'"${PACKAGE_DIR}/yashandb-23.4.14.100-linux-x86_64.tar.gz"$'\tFAILED\t__MYAS_EMPTY__' \
	>>"${CONFIG_DIR}/instances.tsv"
assert_failure run_myas delete legacydb
env HOME="${TMP_DIR}/home" MYAS_CONFIG_DIR="${CONFIG_DIR}" MYAS_TEST_MARKER="${MARKER}" \
	MYAS_PS_BIN="${FAKE_DELETE_PS}" MYAS_SUDO_BIN="${FAKE_SUDO}" \
	script -qec "${ROOT_DIR}/myas.sh delete legacydb" /dev/null <<<y >"${TMP_DIR}/delete-output"
assert_contains 'cleaning instance files without a lifecycle stop' "${TMP_DIR}/delete-output"
assert_contains 'Stopping leftover processes for ys1907: 424242' "${TMP_DIR}/delete-output"
if grep -F $'legacydb\t' "${CONFIG_DIR}/instances.tsv" >/dev/null; then
	echo 'legacy FAILED registration was not removed by delete' >&2
	exit 1
fi
[[ ! -d "${TMP_DIR}/instances/ys1907" ]]

echo "test_cli.sh: passed"
