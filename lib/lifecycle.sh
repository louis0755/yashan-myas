#!/usr/bin/env bash

require_instance() {
	local query=${1:-${YASHANDB_CLUSTER:-}}
	[[ -n ${query} ]] || die "supply an instance or source myas env first"
	load_instance "${query}" || die "unknown instance or cluster: ${query}"
	[[ -x ${INSTANCE_STAGE_DIR}/bin/yasboot ]] || die "yasboot is unavailable: ${INSTANCE_STAGE_DIR}/bin/yasboot"
}

run_lifecycle() {
	local action=$1 query=${2:-}
	require_instance "${query}"
	local yasboot="${INSTANCE_STAGE_DIR}/bin/yasboot"
	local hosts_toml="${INSTANCE_STAGE_DIR}/hosts.toml"

	case "${action}" in
	status)
		"${yasboot}" cluster status -c "${INSTANCE_CLUSTER}" -d
		;;
	shutdown)
		[[ -f ${hosts_toml} ]] || die "hosts.toml is unavailable: ${hosts_toml}"
		"${yasboot}" cluster stop -c "${INSTANCE_CLUSTER}"
		"${yasboot}" process yasagent stop -c "${INSTANCE_CLUSTER}" -t "${hosts_toml}"
		"${yasboot}" process yasom stop -c "${INSTANCE_CLUSTER}" -t "${hosts_toml}"
		update_instance_status "STOPPED"
		;;
	start)
		[[ -f ${hosts_toml} ]] || die "hosts.toml is unavailable: ${hosts_toml}"
		"${yasboot}" process yasom start -c "${INSTANCE_CLUSTER}" -t "${hosts_toml}"
		"${yasboot}" process yasagent start -c "${INSTANCE_CLUSTER}" -t "${hosts_toml}"
		"${yasboot}" cluster start -c "${INSTANCE_CLUSTER}"
		update_instance_status "RUNNING"
		;;
	restart)
		"${yasboot}" cluster restart -c "${INSTANCE_CLUSTER}"
		update_instance_status "RUNNING"
		;;
	*) die "unsupported lifecycle action: ${action}" ;;
	esac
}
