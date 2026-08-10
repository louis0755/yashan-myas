#!/usr/bin/env bash

init_paths() {
	MYAS_CONFIG_DIR=${MYAS_CONFIG_DIR:-"${HOME}/.myas"}
	SETTINGS_FILE="${MYAS_CONFIG_DIR}/settings.conf"
	INSTANCES_FILE="${MYAS_CONFIG_DIR}/instances.tsv"
	MYAS_LOG_DIR="${MYAS_CONFIG_DIR}/logs"
}

find_yinstall_bin() {
	local candidate
	for candidate in \
		"${MYAS_CONFIG_DIR}/yinstall/yinstall.sh" \
		"${MYAS_CONFIG_DIR}/yinstall.sh" \
		"${MYAS_CONFIG_DIR}/yinstall"; do
		if [[ -x ${candidate} ]]; then
			printf '%s' "${candidate}"
			return 0
		fi
	done
	for candidate in yinstall yinstall.sh; do
		if command -v "${candidate}" >/dev/null 2>&1; then
			command -v "${candidate}"
			return 0
		fi
	done
	for candidate in "${MYAS_ROOT}/yinstall/yinstall.sh" "${MYAS_ROOT}/yinstall.sh" "${MYAS_ROOT}/yinstall"; do
		if [[ -x ${candidate} ]]; then printf '%s' "${candidate}"; return 0; fi
	done
	printf '%s' "${MYAS_ROOT}/../yinstall/yinstall.sh"
}

die() {
	printf 'myas: %s\n' "$*" >&2
	exit 1
}

is_identifier() { [[ $1 =~ ^[A-Za-z][A-Za-z0-9_-]{0,63}$ ]]; }
is_cluster_prefix() { [[ $1 =~ ^[A-Za-z][A-Za-z0-9_]{0,62}$ ]]; }
is_port() { [[ $1 =~ ^[1-9][0-9]*$ ]] && (($1 >= 1 && $1 <= 65535)); }
is_host() { [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9.-]{0,253}$ ]]; }
is_absolute_path() { [[ $1 == /* && $1 != / && $1 != *".."* && $1 != *$'\n'* && $1 != *$'\t'* ]]; }
is_safe_field() { [[ $1 != *$'\n'* && $1 != *$'\t'* ]]; }

set_default_settings() {
	BASE_DIR="/data/yashan"
	CLUSTER_PREFIX="ys"
	PACKAGE_DIR="/data/software"
	ARCH="x86_64"
	YINSTALL_BIN=$(find_yinstall_bin)
	SSH_USER="yashan"
	SSH_PORT="22"
	YASOM_PORT_START="1701"
	MYSQL_PORT_START="3307"
	SYS_PASSWORD="__MYAS_SYS_PASSWORD__"
	OS_USER="yashan"
	OS_GROUP="yashan"
	MEMORY_SIZE=""
}

is_setting_key() {
	case "$1" in
	BASE_DIR | CLUSTER_PREFIX | PACKAGE_DIR | ARCH | YINSTALL_BIN | SSH_USER | SSH_PORT | YASOM_PORT_START | MYSQL_PORT_START | SYS_PASSWORD | OS_USER | OS_GROUP | MEMORY_SIZE) return 0 ;;
	*) return 1 ;;
	esac
}

write_default_settings() {
	printf '%s\n' \
		'# myas global configuration' \
		'BASE_DIR=/data/yashan' \
		'CLUSTER_PREFIX=ys' \
		'PACKAGE_DIR=/data/software' \
		'ARCH=x86_64' \
		"YINSTALL_BIN=$(find_yinstall_bin)" \
		'SSH_USER=yashan' \
		'SSH_PORT=22' \
		'YASOM_PORT_START=1701' \
		'MYSQL_PORT_START=3307' \
		'SYS_PASSWORD=__MYAS_SYS_PASSWORD__' \
		'OS_USER=yashan' \
		'OS_GROUP=yashan' >"${SETTINGS_FILE}"
	printf '%s\n' 'MEMORY_SIZE=' >>"${SETTINGS_FILE}"
}

ensure_storage() {
	mkdir -p -- "${MYAS_CONFIG_DIR}" "${MYAS_LOG_DIR}"
	if [[ ! -f ${SETTINGS_FILE} ]]; then
		write_default_settings
	fi
	if grep -q '^MEMORY_LIMIT=' "${SETTINGS_FILE}"; then
		local settings_temp
		settings_temp=$(mktemp "${MYAS_CONFIG_DIR}/settings.XXXXXX")
		awk '$0 !~ /^MEMORY_LIMIT=/' "${SETTINGS_FILE}" >"${settings_temp}"
		mv -- "${settings_temp}" "${SETTINGS_FILE}"
	fi
	chmod 600 -- "${SETTINGS_FILE}"
	if [[ ! -f ${INSTANCES_FILE} ]]; then
		printf '%s\n' '# name version cluster db_port yasom_port yasagent_port replicat_port target install_path data_path log_path stage_dir package status remarks mysql_port' >"${INSTANCES_FILE}"
	fi
}

load_settings() {
	set_default_settings
	local key value
	while IFS='=' read -r key value || [[ -n ${key} ]]; do
		[[ -z ${key} || ${key} == \#* ]] && continue
		is_setting_key "${key}" || die "unsupported setting: ${key}"
		is_safe_field "${value}" || die "unsafe setting value for ${key}"
		case "${key}" in
		BASE_DIR) BASE_DIR=${value} ;;
		CLUSTER_PREFIX) CLUSTER_PREFIX=${value} ;;
		PACKAGE_DIR) PACKAGE_DIR=${value} ;;
		ARCH) ARCH=${value} ;;
		YINSTALL_BIN) YINSTALL_BIN=${value} ;;
		SSH_USER) SSH_USER=${value} ;;
		SSH_PORT) SSH_PORT=${value} ;;
		YASOM_PORT_START) YASOM_PORT_START=${value} ;;
		MYSQL_PORT_START) MYSQL_PORT_START=${value} ;;
		SYS_PASSWORD) [[ -z ${value} ]] || SYS_PASSWORD=${value} ;;
		OS_USER) OS_USER=${value} ;;
		OS_GROUP) OS_GROUP=${value} ;;
		MEMORY_SIZE) MEMORY_SIZE=${value} ;;
		esac
	done <"${SETTINGS_FILE}"

	is_absolute_path "${BASE_DIR}" || die "BASE_DIR must be an absolute safe path"
	is_cluster_prefix "${CLUSTER_PREFIX}" || die "CLUSTER_PREFIX must start with a letter and contain only letters, digits, or underscores"
	is_absolute_path "${PACKAGE_DIR}" || die "PACKAGE_DIR must be an absolute safe path"
	is_port "${SSH_PORT}" || die "SSH_PORT must be a valid port"
	is_port "${YASOM_PORT_START}" && ((YASOM_PORT_START <= 65532)) || die "YASOM_PORT_START must allow three higher ports"
	is_port "${MYSQL_PORT_START}" || die "MYSQL_PORT_START must be a valid port"
	[[ -n ${SYS_PASSWORD} ]] || die "SYS_PASSWORD must not be empty"
	is_identifier "${SSH_USER}" || die "SSH_USER must be an identifier"
	is_identifier "${OS_USER}" || die "OS_USER must be an identifier"
	is_identifier "${OS_GROUP}" || die "OS_GROUP must be an identifier"
	[[ -z ${MEMORY_SIZE} || ${MEMORY_SIZE} =~ ^[1-9][0-9]*([MmGg])?$ ]] || die "MEMORY_SIZE must be an integer with optional M or G suffix"
}

set_setting() {
	local key=$1 value=$2 temp_file
	is_setting_key "${key}" || die "unsupported setting: ${key}"
	is_safe_field "${value}" || die "unsafe setting value"
	temp_file=$(mktemp "${MYAS_CONFIG_DIR}/settings.XXXXXX")
	awk -F= -v key="${key}" -v value="${value}" '
		$1 == key { print key "=" value; found = 1; next }
		{ print }
		END { if (!found) print key "=" value }
	' "${SETTINGS_FILE}" >"${temp_file}"
	mv -- "${temp_file}" "${SETTINGS_FILE}"
	load_settings
}

reset_instance() {
	INSTANCE_NAME=""
	INSTANCE_VERSION=""
	INSTANCE_CLUSTER=""
	INSTANCE_DB_PORT=""
	INSTANCE_YASOM_PORT=""
	INSTANCE_YASAGENT_PORT=""
	INSTANCE_REPLICAT_PORT=""
	INSTANCE_MYSQL_PORT=""
	INSTANCE_TARGET=""
	INSTANCE_INSTALL_PATH=""
	INSTANCE_DATA_PATH=""
	INSTANCE_LOG_PATH=""
	INSTANCE_STAGE_DIR=""
	INSTANCE_PACKAGE=""
	INSTANCE_STATUS=""
	INSTANCE_REMARKS=""
}

load_instance() {
	local query=$1 name version cluster db_port yasom_port yasagent_port replicat_port target install_path data_path log_path stage_dir package status remarks mysql_port
	reset_instance
	while IFS=$'\t' read -r name version cluster db_port yasom_port yasagent_port replicat_port target install_path data_path log_path stage_dir package status remarks mysql_port || [[ -n ${name} ]]; do
		[[ -z ${name} || ${name} == \#* ]] && continue
		if [[ ${name} == "${query}" || ${cluster} == "${query}" ]]; then
			INSTANCE_NAME=${name}
			INSTANCE_VERSION=${version}
			INSTANCE_CLUSTER=${cluster}
			INSTANCE_DB_PORT=${db_port}
			INSTANCE_YASOM_PORT=${yasom_port}
			INSTANCE_YASAGENT_PORT=${yasagent_port}
			INSTANCE_REPLICAT_PORT=${replicat_port}
			INSTANCE_MYSQL_PORT=${mysql_port}
			INSTANCE_TARGET=${target}
			INSTANCE_INSTALL_PATH=${install_path}
			INSTANCE_DATA_PATH=${data_path}
			INSTANCE_LOG_PATH=${log_path}
			INSTANCE_STAGE_DIR=${stage_dir}
			INSTANCE_PACKAGE=${package}
			INSTANCE_STATUS=${status}
			INSTANCE_REMARKS=${remarks}
			[[ ${INSTANCE_REMARKS} != __MYAS_EMPTY__ ]] || INSTANCE_REMARKS=""
			return 0
		fi
	done <"${INSTANCES_FILE}"
	return 1
}

append_instance() {
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"${INSTANCE_NAME}" "${INSTANCE_VERSION}" "${INSTANCE_CLUSTER}" "${INSTANCE_DB_PORT}" \
		"${INSTANCE_YASOM_PORT}" "${INSTANCE_YASAGENT_PORT}" "${INSTANCE_REPLICAT_PORT}" \
		"${INSTANCE_TARGET}" "${INSTANCE_INSTALL_PATH}" "${INSTANCE_DATA_PATH}" "${INSTANCE_LOG_PATH}" \
		"${INSTANCE_STAGE_DIR}" "${INSTANCE_PACKAGE}" "${INSTANCE_STATUS}" "${INSTANCE_REMARKS:-__MYAS_EMPTY__}" "${INSTANCE_MYSQL_PORT}" >>"${INSTANCES_FILE}"
}

update_instance_status() {
	local status=$1 temp_file name
	temp_file=$(mktemp "${MYAS_CONFIG_DIR}/instances.XXXXXX")
	while IFS= read -r name || [[ -n ${name} ]]; do
		if [[ ${name} == "${INSTANCE_NAME}"$'\t'* ]]; then
			printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
				"${INSTANCE_NAME}" "${INSTANCE_VERSION}" "${INSTANCE_CLUSTER}" "${INSTANCE_DB_PORT}" \
				"${INSTANCE_YASOM_PORT}" "${INSTANCE_YASAGENT_PORT}" "${INSTANCE_REPLICAT_PORT}" \
				"${INSTANCE_TARGET}" "${INSTANCE_INSTALL_PATH}" "${INSTANCE_DATA_PATH}" "${INSTANCE_LOG_PATH}" \
				"${INSTANCE_STAGE_DIR}" "${INSTANCE_PACKAGE}" "${status}" "${INSTANCE_REMARKS:-__MYAS_EMPTY__}" "${INSTANCE_MYSQL_PORT}" >>"${temp_file}"
		else
			printf '%s\n' "${name}" >>"${temp_file}"
		fi
	done <"${INSTANCES_FILE}"
	mv -- "${temp_file}" "${INSTANCES_FILE}"
	INSTANCE_STATUS=${status}
}

port_group_available() {
	local db_port=$1 mysql_port=${2:-} yasom_port=$((db_port - 2)) yasagent_port=$((db_port - 1)) replicat_port=$((db_port + 1))
	local name version cluster existing_db existing_yasom existing_yasagent existing_replicat target install_path data_path log_path stage_dir package status remarks existing_mysql
	local candidate_port existing_port
	while IFS=$'\t' read -r name version cluster existing_db existing_yasom existing_yasagent existing_replicat target install_path data_path log_path stage_dir package status remarks existing_mysql || [[ -n ${name} ]]; do
		[[ -z ${name} || ${name} == \#* ]] && continue
		for candidate_port in "${yasom_port}" "${yasagent_port}" "${db_port}" "${replicat_port}" ${mysql_port:+"${mysql_port}"}; do
			for existing_port in "${existing_yasom}" "${existing_yasagent}" "${existing_db}" "${existing_replicat}" ${existing_mysql:+"${existing_mysql}"}; do
				[[ ${candidate_port} != "${existing_port}" ]] || return 1
			done
		done
	done <"${INSTANCES_FILE}"
	return 0
}

next_available_mysql_port() {
	local candidate=${MYSQL_PORT_START}
	while ((candidate <= 65535)); do
		if managed_port_available "${candidate}"; then
			printf '%s' "${candidate}"
			return 0
		fi
		candidate=$((candidate + 1))
	done
	die "no available MySQL port remains"
}

managed_port_available() {
	local candidate=$1 name version cluster db_port yasom_port yasagent_port replicat_port target install_path data_path log_path stage_dir package status remarks mysql_port existing_port
	while IFS=$'\t' read -r name version cluster db_port yasom_port yasagent_port replicat_port target install_path data_path log_path stage_dir package status remarks mysql_port || [[ -n ${name} ]]; do
		[[ -z ${name} || ${name} == \#* ]] && continue
		for existing_port in "${yasom_port}" "${yasagent_port}" "${db_port}" "${replicat_port}" ${mysql_port:+"${mysql_port}"}; do
			[[ ${candidate} != "${existing_port}" ]] || return 1
		done
	done <"${INSTANCES_FILE}"
	return 0
}

next_available_db_port() {
	local candidate=$((YASOM_PORT_START + 2))
	while ((candidate <= 65534)); do
		if port_group_available "${candidate}"; then
			printf '%s' "${candidate}"
			return 0
		fi
		candidate=$((candidate + 4))
	done
	die "no available database port group remains"
}
