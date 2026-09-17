#!/usr/bin/env bash

hostcheck_memory_mib() {
	local value=${1:-}
	[[ -z ${value} ]] && return 0
	local number=${value%[MmGg]}
	case ${value} in
	*[Gg]) printf '%s' "$((number * 1024))" ;;
	*) printf '%s' "${number}" ;;
	esac
}

hostcheck_one() {
	local host=$1 local_mode=${2:-false} remote_output expected_memory
	expected_memory=$(hostcheck_memory_mib "${MEMORY_SIZE}")
	printf '\n[%s]\n' "${host}"
	if ! is_host "${host}"; then
		printf 'FAIL  host: invalid host name or address\nNEED  provide a valid hostname or IP address\n'
		return 1
	fi
	local remote_script
	remote_script=$(cat <<EOF
set -u
printf 'HOSTNAME=%s\\n' "\$(hostname 2>/dev/null || printf unknown)"
printf 'ARCH=%s\\n' "\$(uname -m 2>/dev/null || printf unknown)"
if [ -r /etc/os-release ]; then . /etc/os-release; printf 'OS=%s %s\\n' "\${ID:-unknown}" "\${VERSION_ID:-unknown}"; else printf 'OS=unknown unknown\\n'; fi
printf 'CPU=%s\\n' "\$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 0)"
awk '/^MemTotal:/ {printf "MEM_TOTAL_MIB=%d\\n", \$2/1024; next} /^MemAvailable:/ {printf "MEM_AVAILABLE_MIB=%d\\n", \$2/1024}' /proc/meminfo 2>/dev/null || true
df -Pk -- "$(dirname -- "${BASE_DIR}")" 2>/dev/null | awk 'NR==2 {printf "BASE_FREE_MIB=%d\\n", \$4/1024}' || true
if [ -d "${BASE_DIR}" ]; then [ -w "${BASE_DIR}" ] && printf 'BASE_WRITABLE=ok\\n' || printf 'BASE_WRITABLE=missing\\n'; else [ -w "$(dirname -- "${BASE_DIR}")" ] && printf 'BASE_WRITABLE=ok\\n' || printf 'BASE_WRITABLE=missing\\n'; fi
id "${OS_USER}" >/dev/null 2>&1 && printf 'OS_USER=ok\\n' || printf 'OS_USER=missing\\n'
getent group "${OS_GROUP}" >/dev/null 2>&1 && printf 'OS_GROUP=ok\\n' || printf 'OS_GROUP=missing\\n'
sudo -n true >/dev/null 2>&1 && printf 'SUDO=ok\\n' || printf 'SUDO=missing\\n'
for command_name in bash awk tar systemctl install getconf; do command -v "\${command_name}" >/dev/null 2>&1 && printf 'CMD_%s=ok\\n' "\${command_name}" || printf 'CMD_%s=missing\\n' "\${command_name}"; done
path_name="${BASE_DIR}"; [ -d "\${path_name}" ] && printf 'DIR_%s=ok\\n' "\${path_name}" || printf 'DIR_%s=missing\\n' "\${path_name}"
EOF
)
	if [[ ${local_mode} == true ]]; then
		if ! remote_output=$(bash -se <<<"${remote_script}" 2>&1); then
			printf 'FAIL  local host check failed\n'
			printf '%s\n' "${remote_output}" | sed 's/^/      /'
			return 1
		fi
	else
		local ssh_args=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -p "${SSH_PORT}")
		[[ -z ${SSH_KEY_PATH:-} ]] || ssh_args+=(-i "${SSH_KEY_PATH}")
		if ! remote_output=$(ssh "${ssh_args[@]}" "${SSH_USER}@${host}" 'bash -se' <<<"${remote_script}" 2>&1); then
			printf 'FAIL  ssh: connection or remote command failed\nNEED  passwordless SSH for %s@%s on port %s\n' "${SSH_USER}" "${host}" "${SSH_PORT}"
			printf '%s\n' "${remote_output}" | sed 's/^/      /'
			return 1
		fi
	fi
	local key value failures=0 warnings=0
	while IFS='=' read -r key value; do
		case ${key} in
		HOSTNAME) printf 'INFO  hostname: %s\n' "${value}" ;;
		ARCH) printf 'INFO  arch: %s (configured %s)\n' "${value}" "${ARCH}"; [[ ${value} == "${ARCH}" ]] || { printf 'FAIL  configured ARCH=%s does not match host %s\n' "${ARCH}" "${value}"; ((failures+=1)); } ;;
		OS) printf 'INFO  os: %s\n' "${value}"; case ${value%% *} in rhel|rocky|almalinux|ol|centos|kylin|uos|ubuntu|debian) ;; *) printf 'FAIL  unsupported Linux distribution: %s\n' "${value}"; ((failures+=1)) ;; esac ;;
		CPU) printf 'INFO  cpu: %s logical CPUs\n' "${value}"; ((value >= 2)) || { printf 'FAIL  at least 2 logical CPUs required\n'; ((failures+=1)); } ;;
		MEM_TOTAL_MIB) printf 'INFO  memory: %s MiB total\n' "${value}"; [[ -z ${expected_memory} || ${value} -ge ${expected_memory} ]] || { printf 'FAIL  MEMORY_SIZE=%s requires at least %s MiB\n' "${MEMORY_SIZE}" "${expected_memory}"; ((failures+=1)); } ;;
		MEM_AVAILABLE_MIB) printf 'INFO  memory: %s MiB available\n' "${value}" ;;
		BASE_FREE_MIB) printf 'INFO  %s free: %s MiB\n' "${BASE_DIR}" "${value}"; if ((value < 5120)); then printf 'FAIL  less than 5 GiB free under BASE_DIR\n'; ((failures+=1)); elif ((value < 20480)); then printf 'WARN  less than 20 GiB free under BASE_DIR\n'; ((warnings+=1)); fi ;;
		BASE_WRITABLE) [[ ${value} == ok ]] || { printf 'FAIL  %s is not writable by %s\n' "${BASE_DIR}" "${SSH_USER}"; ((failures+=1)); } ;;
		OS_USER) [[ ${value} == ok ]] || { printf 'FAIL  OS_USER=%s is missing\n' "${OS_USER}"; ((failures+=1)); } ;;
		OS_GROUP) [[ ${value} == ok ]] || { printf 'FAIL  OS_GROUP=%s is missing\n' "${OS_GROUP}"; ((failures+=1)); } ;;
		SUDO) [[ ${value} == ok ]] || { printf 'FAIL  sudo -n is unavailable for %s\n' "${SSH_USER}"; ((failures+=1)); } ;;
		CMD_*) [[ ${value} == ok ]] || { printf 'FAIL  required command missing: %s\n' "${key#CMD_}"; ((failures+=1)); } ;;
		DIR_*) [[ ${value} == ok ]] || { printf 'WARN  directory will be created by installer: %s\n' "${key#DIR_}"; ((warnings+=1)); } ;;
		esac
	done <<<"${remote_output}"
	if ((failures == 0)); then printf 'PASS  host meets myas baseline (%s warning(s))\n' "${warnings}"; return 0; fi
	printf 'NEED  fix the FAIL items above before deployment\n'
	return 1
}

check_hosts() {
	(($# > 0)) || die 'usage: check HOST [HOST...] | check --local'
	local host failed=0 local_mode=false
	if [[ ${1} == --local ]]; then
		(($# == 1)) || die 'usage: check HOST [HOST...] | check --local'
		local_mode=true
		host=$(hostname 2>/dev/null || printf local)
		set --
	fi
	printf 'myas host precheck (ARCH=%s, BASE_DIR=%s, PACKAGE_DIR=%s)\n' "${ARCH}" "${BASE_DIR}" "${PACKAGE_DIR}"
	if [[ ! -d ${PACKAGE_DIR} ]]; then
		printf 'WARN  local package directory is missing: %s (copy packages before create)\n' "${PACKAGE_DIR}"
	elif ! compgen -G "${PACKAGE_DIR}/yashandb-*-linux-${ARCH}.tar.gz" >/dev/null; then
		printf 'WARN  no standard %s package found in %s (use --package for another filename)\n' "${ARCH}" "${PACKAGE_DIR}"
	fi
	if [[ ${local_mode} == true ]]; then
		hostcheck_one "${host}" true || failed=1
	else
		while (($#)); do host=$1; shift; hostcheck_one "${host}" || failed=1; done
	fi
	if ((failed)); then printf '\nOverall: FAIL; see NEED lines for missing information or remediation.\n'; return 1; fi
	printf '\nOverall: PASS; hosts satisfy the configured myas baseline.\n'
}
