#!/usr/bin/env bash

instance_is_running() {
	local data_path=${1%/}/ ps_bin=${MYAS_PS_BIN:-ps}
	"${ps_bin}" -eo args= 2>/dev/null | awk -v data_path="${data_path}" '
		{
			for (i = 1; i <= NF - 3; i++) {
				if ($i ~ /(^|\/)yasdb$/ && $(i + 1) ~ /^(open|mount|nomount)$/ && $(i + 2) == "-D" && index($(i + 3), data_path) == 1) {
					found = 1
				}
			}
		}
		END { exit(found ? 0 : 1) }
	'
}

instance_display_status() {
	local stored_status=$1 data_path=$2
	if [[ ${stored_status} == FAILED ]]; then
		printf 'FAIL'
	elif instance_is_running "${data_path}"; then
		printf 'RUNNING'
	elif [[ ${stored_status} == INSTALLED || ${stored_status} == RUNNING || ${stored_status} == STOPPED ]]; then
		printf 'INSTALLED'
	else
		printf 'NOT RUN'
	fi
}

list_instances() {
	local current_cluster=${YASHANDB_CLUSTER:-} remarks current mysql_display display_status
	printf '%-16s %-14s %-8s %-12s %-12s %-20s %s\n' NAME VERSION PORT MYSQL STATUS REMARKS CURRENT
	while IFS=$'\t' read -r name version cluster db_port yasom_port yasagent_port replicat_port target install_path data_path log_path stage_dir package status remarks mysql_port || [[ -n ${name} ]]; do
		[[ -z ${name} || ${name} == \#* ]] && continue
		current=""
		[[ ${cluster} == "${current_cluster}" ]] && current='*'
		[[ ${remarks} != __MYAS_EMPTY__ ]] || remarks=""
		[[ -n ${remarks} ]] || remarks=${name}
		mysql_display="No"
		[[ -z ${mysql_port} ]] || mysql_display="Yes (${mysql_port})"
		display_status=$(instance_display_status "${status}" "${data_path}")
		printf '%-16s %-14s %-8s %-12s %-12s %-20s %s\n' "${cluster}" "${version}" "${db_port}" "${mysql_display}" "${display_status}" "${remarks}" "${current}"
	done <"${INSTANCES_FILE}"
}

show_instance() {
	load_instance "$1" || die "unknown instance or cluster: $1"
	local display_status
	display_status=$(instance_display_status "${INSTANCE_STATUS}" "${INSTANCE_DATA_PATH}")
	printf 'Name:          %s\n' "${INSTANCE_NAME}"
	printf 'Version:       %s\n' "${INSTANCE_VERSION}"
	printf 'Cluster:       %s\n' "${INSTANCE_CLUSTER}"
	printf 'Target:        %s\n' "${INSTANCE_TARGET}"
	printf 'Status:        %s\n' "${display_status}"
	printf 'Yasom port:    %s\n' "${INSTANCE_YASOM_PORT}"
	printf 'Yasagent port: %s\n' "${INSTANCE_YASAGENT_PORT}"
	printf 'YashanDB port: %s\n' "${INSTANCE_DB_PORT}"
	printf 'Replicat port: %s\n' "${INSTANCE_REPLICAT_PORT}"
	[[ -z ${INSTANCE_MYSQL_PORT} ]] || printf 'MySQL port:    %s\n' "${INSTANCE_MYSQL_PORT}"
	printf 'Install path:  %s\n' "${INSTANCE_INSTALL_PATH}"
	printf 'Data path:     %s\n' "${INSTANCE_DATA_PATH}"
	printf 'Log path:      %s\n' "${INSTANCE_LOG_PATH}"
	printf 'Stage path:    %s\n' "${INSTANCE_STAGE_DIR}"
	printf 'Package:       %s\n' "${INSTANCE_PACKAGE}"
	[[ -z ${INSTANCE_REMARKS} ]] || printf 'Remarks:       %s\n' "${INSTANCE_REMARKS}"
}

emit_environment() {
	load_instance "$1" || die "unknown instance or cluster: $1"
	local yasboot_env="${HOME}/.yasboot/${INSTANCE_CLUSTER}_yasdb_home/conf/${INSTANCE_CLUSTER}.bashrc"
	if [[ -f ${yasboot_env} ]]; then
		printf 'source %q\n' "${yasboot_env}"
	else
		printf 'export YASDB_HOME=%q\n' "${INSTANCE_INSTALL_PATH}/${INSTANCE_VERSION}"
		printf 'export YASDB_DATA=%q\n' "${INSTANCE_DATA_PATH}/db-1-1"
		printf 'export PATH=%q:$PATH\n' "${INSTANCE_INSTALL_PATH}/${INSTANCE_VERSION}/bin"
		printf 'export LD_LIBRARY_PATH=%q:${LD_LIBRARY_PATH:-}\n' "${INSTANCE_INSTALL_PATH}/${INSTANCE_VERSION}/lib"
	fi
	printf 'export YASHANDB_NAME=%q\n' "${INSTANCE_NAME}"
	printf 'export YASHANDB_VERSION=%q\n' "${INSTANCE_VERSION}"
	printf 'export YASHANDB_CLUSTER=%q\n' "${INSTANCE_CLUSTER}"
	printf 'export YASHANDB_YASOM_PORT=%q\n' "${INSTANCE_YASOM_PORT}"
	printf 'export YASHANDB_YASAGENT_PORT=%q\n' "${INSTANCE_YASAGENT_PORT}"
	printf 'export YASHANDB_PORT=%q\n' "${INSTANCE_DB_PORT}"
	printf 'export YASHANDB_REPLICAT_PORT=%q\n' "${INSTANCE_REPLICAT_PORT}"
	[[ -z ${INSTANCE_MYSQL_PORT} ]] || printf 'export YASHANDB_MYSQL_PORT=%q\n' "${INSTANCE_MYSQL_PORT}"
	printf 'export YASHANDB_HOME=%q\n' "${INSTANCE_INSTALL_PATH}"
	printf 'export YASHANDB_DATA=%q\n' "${INSTANCE_DATA_PATH}"
	printf 'export YASHANDB_LOG=%q\n' "${INSTANCE_LOG_PATH}"
	printf 'export MYAS_YASBOOT=%q\n' "${INSTANCE_STAGE_DIR}/bin/yasboot"
	printf 'alias ystatus=%q\n' "${MYAS_BIN} status ${INSTANCE_CLUSTER}"
	printf 'alias ystart=%q\n' "${MYAS_BIN} start ${INSTANCE_CLUSTER}"
	printf 'alias yshutdown=%q\n' "${MYAS_BIN} shutdown ${INSTANCE_CLUSTER}"
	printf 'alias yrestart=%q\n' "${MYAS_BIN} restart ${INSTANCE_CLUSTER}"
}

emit_aliases() {
	local name version cluster rest command=${MYAS_BIN}
	[[ -x ${HOME}/.local/bin/myas ]] && command="${HOME}/.local/bin/myas"
	while IFS=$'\t' read -r name version cluster rest || [[ -n ${name} ]]; do
		[[ -z ${name} || ${name} == \#* ]] && continue
		printf "alias %s='source <(%q env %q)'\n" "${cluster}" "${command}" "${cluster}"
	done <"${INSTANCES_FILE}"
}

emit_shell_init() {
	local command=${MYAS_BIN}
	[[ -x ${HOME}/.local/bin/myas ]] && command="${HOME}/.local/bin/myas"
	printf 'myas() { %q "$@"; }\n' "${command}"
	printf 'myas_refresh() { eval "$(%q alias)"; }\n' "${command}"
	printf 'myas_refresh\n'
}

create_instance() {
	local name=$1 version=$2
	shift 2
	local target="" db_port="" package="" remarks="" memory_size="${MEMORY_SIZE}" precheck=false dry_run=false force=false local_mode=true local_explicit=false
	local mysql_mode=false mysql_port=""
	while (($#)); do
		case "$1" in
		--target)
			[[ ${local_explicit} == false ]] || die "--local cannot be combined with --target"
			target=${2:?missing value for $1}
			local_mode=false
			shift 2
			;;
		--local)
			[[ -z ${target} ]] || die "--local cannot be combined with --target"
			local_mode=true
			local_explicit=true
			shift
			;;
		--db-port) db_port=${2:?missing value for $1}; shift 2 ;;
		--package) package=${2:?missing value for $1}; shift 2 ;;
		--remarks) remarks=${2:?missing value for $1}; shift 2 ;;
		--precheck) precheck=true; shift ;;
		--dry-run) dry_run=true; shift ;;
		--force) force=true; shift ;;
		--memory-size) memory_size=${2:?missing value for $1}; shift 2 ;;
		--mysql) mysql_mode=true; shift ;;
		--mysql-port) mysql_mode=true; mysql_port=${2:?missing value for $1}; shift 2 ;;
		*) die "unknown create option: $1" ;;
		esac
	done

	is_identifier "${name}" || die "instance name must be an identifier"
	[[ ${SYS_PASSWORD} != __MYAS_SYS_PASSWORD__ ]] || die "SYS_PASSWORD is not configured; deploy the package or run config set SYS_PASSWORD"
	[[ ${version} =~ ^[0-9]+(\.[0-9]+)+$ ]] || die "version must use dotted numeric form"
	if [[ ${local_mode} == false ]]; then
		is_host "${target}" || die "--target must be a valid host"
	else
		target="local"
	fi
	if [[ -z ${db_port} ]]; then
		db_port=$(next_available_db_port)
	fi
	is_port "${db_port}" && ((db_port >= 3 && db_port <= 65534)) || die "--db-port must allow two lower and one higher port"
	is_safe_field "${remarks}" || die "remarks cannot contain tabs or newlines"
	[[ -z ${memory_size} || ${memory_size} =~ ^[1-9][0-9]*([MmGg])?$ ]] || die "--memory-size must be an integer with optional M or G suffix"
	if [[ ${mysql_mode} == true ]]; then
		[[ -n ${mysql_port} ]] || mysql_port=$(next_available_mysql_port)
		is_port "${mysql_port}" || die "--mysql-port must be a valid port"
	fi

	local cluster="${CLUSTER_PREFIX}${db_port}"
	local db_basedir="${BASE_DIR}/${cluster}"
	if [[ -z ${package} ]]; then
		package="${PACKAGE_DIR}/yashandb-${version}-linux-${ARCH}.tar.gz"
	fi
	[[ -f ${package} ]] || die "package not found: ${package}"
	if [[ ${YINSTALL_BIN} != */* ]]; then
		command -v -- "${YINSTALL_BIN}" >/dev/null 2>&1 || die "YINSTALL_BIN was not found in PATH: ${YINSTALL_BIN}"
	else
		[[ -x ${YINSTALL_BIN} ]] || die "YINSTALL_BIN is not executable: ${YINSTALL_BIN}"
	fi
	load_instance "${name}" && die "instance already exists: ${name}"
	load_instance "${cluster}" && die "cluster already exists: ${cluster}"
	port_group_available "${db_port}" "${mysql_port}" || die "port group conflicts with an existing instance"

	INSTANCE_NAME=${name}
	INSTANCE_VERSION=${version}
	INSTANCE_CLUSTER=${cluster}
	INSTANCE_DB_PORT=${db_port}
	INSTANCE_YASOM_PORT=$((db_port - 2))
	INSTANCE_YASAGENT_PORT=$((db_port - 1))
	INSTANCE_REPLICAT_PORT=$((db_port + 1))
	INSTANCE_MYSQL_PORT=${mysql_port}
	INSTANCE_TARGET=${target}
	INSTANCE_INSTALL_PATH="${db_basedir}/yasdb-home"
	INSTANCE_DATA_PATH="${db_basedir}/yasdb-data"
	INSTANCE_LOG_PATH="${db_basedir}/yasdb-log"
	INSTANCE_STAGE_DIR="${db_basedir}/install"
	INSTANCE_PACKAGE=${package}
	INSTANCE_STATUS="INSTALLING"
	INSTANCE_REMARKS=${remarks}
	append_instance

	local -a command
	command=("${YINSTALL_BIN}" db install --package "${package}" --db-admin-password "${SYS_PASSWORD}"
		--cluster "${cluster}" --db-port "${db_port}" --install-path "${INSTANCE_INSTALL_PATH}"
		--data-path "${INSTANCE_DATA_PATH}" --log-path "${INSTANCE_LOG_PATH}" --stage-dir "${INSTANCE_STAGE_DIR}"
		--os-user "${OS_USER}" --os-group "${OS_GROUP}"
		--log-dir "${MYAS_LOG_DIR}/${cluster}")
	[[ -z ${memory_size} ]] || command+=(--memory-size "${memory_size}")
	[[ ${mysql_mode} == false ]] || command+=(--mode mysql --mysql-port "${mysql_port}")
	if [[ ${local_mode} == true ]]; then
		command+=(--local)
	else
		command+=(--target "${target}" --ssh-user "${SSH_USER}" --ssh-port "${SSH_PORT}")
	fi
	[[ ${precheck} == true ]] && command+=(--precheck)
	[[ ${dry_run} == true ]] && command+=(--dry-run)
	[[ ${force} == true ]] && command+=(--force)

	if "${command[@]}"; then
		if [[ ${dry_run} == true || ${precheck} == true ]]; then
			update_instance_status "PLANNED"
		else
			update_instance_status "INSTALLED"
		fi
	else
		update_instance_status "FAILED"
		return 1
	fi
}

delete_instance() {
	local query=$1 answer temp_file
	load_instance "${query}" || die "unknown instance or cluster: ${query}"
	[[ -t 0 ]] || die "delete requires an interactive terminal"
	printf '即将删除数据库：\n'
	printf '  CLUSTER_NAME: %s\n' "${INSTANCE_CLUSTER}"
	printf '  YASDB_HOME:   %s\n' "${INSTANCE_INSTALL_PATH}"
	printf '  YASDB_DATA:   %s\n' "${INSTANCE_DATA_PATH}"
	printf '  YASBOOT_ENV:  %s\n' "${HOME}/.yasboot/${INSTANCE_CLUSTER}.env"
	printf '  YASBOOT_HOME: %s\n' "${HOME}/.yasboot/${INSTANCE_CLUSTER}_yasdb_home"
	printf '确认删除并清理以上目录？仅输入 y 继续: '
	IFS= read -r answer
	[[ ${answer} == y ]] || { printf '已取消。\n'; return 1; }
	[[ ${INSTANCE_TARGET} == local ]] || die "remote instance deletion is not supported"
	run_lifecycle shutdown "${INSTANCE_CLUSTER}" || true
	for managed_path in "${INSTANCE_INSTALL_PATH}" "${INSTANCE_DATA_PATH}" "${INSTANCE_LOG_PATH}" "${INSTANCE_STAGE_DIR}"; do
		[[ ${managed_path} == "${BASE_DIR}/${INSTANCE_CLUSTER}/"* ]] || die "refusing to delete unsafe path: ${managed_path}"
	done
	/usr/bin/sudo -n rm -rf -- "${INSTANCE_INSTALL_PATH}" "${INSTANCE_DATA_PATH}" "${INSTANCE_LOG_PATH}" "${INSTANCE_STAGE_DIR}"
	rm -f -- "${HOME}/.yasboot/${INSTANCE_CLUSTER}.env" "${HOME}/.yasboot/${INSTANCE_CLUSTER}_yasdb_home"
	temp_file=$(mktemp "${MYAS_CONFIG_DIR}/instances.XXXXXX")
	awk -F '\t' -v name="${INSTANCE_NAME}" '$1 != name' "${INSTANCES_FILE}" >"${temp_file}"
	mv -- "${temp_file}" "${INSTANCES_FILE}"
}
