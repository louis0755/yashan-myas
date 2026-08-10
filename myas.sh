#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

MYAS_BIN=$(readlink -f -- "${BASH_SOURCE[0]}")
MYAS_ROOT=$(cd -- "$(dirname -- "${MYAS_BIN}")" && pwd)
VERSION=$(<"${MYAS_ROOT}/VERSION")
# shellcheck source=lib/myas-common.sh
source "${MYAS_ROOT}/lib/myas-common.sh"
# shellcheck source=lib/instances.sh
source "${MYAS_ROOT}/lib/instances.sh"
# shellcheck source=lib/lifecycle.sh
source "${MYAS_ROOT}/lib/lifecycle.sh"

usage() {
	printf 'myas %s\n\n' "${VERSION}"
	cat <<'EOF'
Usage:
  myas.sh create NAME VERSION [--db-port PORT] [--target HOST] [options]
  myas.sh [list] | info NAME_OR_CLUSTER | env NAME_OR_CLUSTER | alias | shell-init
  myas.sh status|start|shutdown|restart [NAME_OR_CLUSTER]
  myas.sh config show | config set KEY VALUE

Create options:
	--local              Deploy on this host (the default)
	--target HOST        Deploy remotely
	--db-port PORT       Database port; defaults to the next available port group
  --package FILE       Override PACKAGE_DIR/yashandb-VERSION-linux-ARCH.tar.gz
  --remarks TEXT       Store a short instance note
  --precheck           Ask yinstall to validate without mutation
  --dry-run            Ask yinstall to print planned mutation
  --force              Allow cleanup of stale managed installation files
  --memory-size SIZE   Memory target for this deployment; integer M(default) or G

Global settings: BASE_DIR, CLUSTER_PREFIX, PACKAGE_DIR, ARCH, YINSTALL_BIN,
SSH_USER, SSH_PORT, YASOM_PORT_START, SYS_PASSWORD, OS_USER, OS_GROUP, MEMORY_LIMIT, MEMORY_SIZE.
EOF
}

show_config() {
	printf 'Configuration: %s\n' "${SETTINGS_FILE}"
	printf 'BASE_DIR=%s\n' "${BASE_DIR}"
	printf 'CLUSTER_PREFIX=%s\n' "${CLUSTER_PREFIX}"
	printf 'PACKAGE_DIR=%s\n' "${PACKAGE_DIR}"
	printf 'ARCH=%s\n' "${ARCH}"
	printf 'YINSTALL_BIN=%s\n' "${YINSTALL_BIN}"
	printf 'SSH_USER=%s\n' "${SSH_USER}"
	printf 'SSH_PORT=%s\n' "${SSH_PORT}"
	printf 'YASOM_PORT_START=%s\n' "${YASOM_PORT_START}"
	printf 'SYS_PASSWORD=********\n'
	printf 'OS_USER=%s\n' "${OS_USER}"
	printf 'OS_GROUP=%s\n' "${OS_GROUP}"
	printf 'MEMORY_LIMIT=%s\n' "${MEMORY_LIMIT}"
	printf 'MEMORY_SIZE=%s\n' "${MEMORY_SIZE}"
}

main() {
	init_paths
	ensure_storage
	load_settings
	local command=${1:-list}
	shift || true
	case "${command}" in
	create) (($# >= 2)) || die "usage: create NAME VERSION [--db-port PORT] [--target HOST]"; create_instance "$@" ;;
	list) (($# == 0)) || die "list takes no arguments"; list_instances ;;
	info) (($# == 1)) || die "usage: info NAME_OR_CLUSTER"; show_instance "$1" ;;
	env) (($# == 1)) || die "usage: env NAME_OR_CLUSTER"; emit_environment "$1" ;;
	alias) (($# == 0)) || die "alias takes no arguments"; emit_aliases ;;
	shell-init) (($# == 0)) || die "shell-init takes no arguments"; emit_shell_init ;;
	status | start | shutdown | restart) (($# <= 1)) || die "usage: ${command} [NAME_OR_CLUSTER]"; run_lifecycle "${command}" "${1:-}" ;;
	delete) (($# == 1)) || die "usage: delete NAME_OR_CLUSTER"; delete_instance "$1" ;;
	config)
		case "${1:-}" in
		show) (($# == 1)) || die "usage: config show"; show_config ;;
		set) (($# == 3)) || die "usage: config set KEY VALUE"; set_setting "$2" "$3"; show_config ;;
		*) die "usage: config show | config set KEY VALUE" ;;
		esac
		;;
	version | --version) printf 'myas %s\n' "${VERSION}" ;;
	help | -h | --help) usage ;;
	*) die "unknown command: ${command}" ;;
	esac
}

main "$@"
