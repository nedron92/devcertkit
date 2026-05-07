#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## Load variables and basic functionality
# shellcheck source=./common/shared.sh
source "${SCRIPT_DIR}/common/shared.sh"
# shellcheck source=./common/paths.sh
source "${SCRIPT_DIR}/common/paths.sh"
# shellcheck source=./common/easyrsa-prepare.sh
source "${SCRIPT_DIR}/common/easyrsa-prepare.sh"

##
show_help() {
  cat <<EOF
Usage: ./${SCRIPT_NAME} [options]

Initializes the devcertkit workspace and EasyRSA backend.

Options:
  -h, --help               Show this help message
  --easyrsa-path <path>    Path to the installed EasyRSA directory

This command:
- prepares workspace directories
- initializes EasyRSA PKI for SSL
- does not create a CA certificate yet
EOF
}

init_easyrsa() {
  local easyrsa_path="${1:-${EASYRSA_PATH:-}}"
  local easyrsa_path_found

  easyrsa_path_found="$(resolve_easyrsa "$easyrsa_path")"
  ln -sfn "$easyrsa_path_found" "${EASYRSA_DIR}"

  check_dir "${EASYRSA_DIR}"
  check_file "${EASYRSA_BIN}"
  export EASYRSA_PKI="${SSL_PKI_DIR}"

  prepare_dir "${SSL_OUTPUT_DIR}"

  if [[ ! -d "${SSL_PKI_DIR}/private" ]]; then
    info "Initializing EasyRSA PKI..."
    # Ensure directory is empty/clean for init-pki to avoid confirmation prompt
    rm -rf "${SSL_PKI_DIR}"
    # EasyRSA / OpenSSL compatibility seed file
    "${EASYRSA_BIN}" init-pki
    openssl rand -writerand "${SSL_PKI_DIR}/.rnd"
  else
    info "EasyRSA PKI already exists: ${EASYRSA_PKI}"
  fi
}

main() {
  local user_easyrsa_path=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      --easyrsa-path)
        if [[ -n "${2:-}" && "$2" != -* ]]; then
          user_easyrsa_path="$2"
          shift 2
        else
          fail "--easyrsa-path requires an argument."
        fi
        ;;
      *)
        fail "Unknown argument: $1"
        ;;
    esac
  done

  info "Initializing devcertkit workspace..."

  info "Preparing folder and workspace structure."
  prepare_dir "${RUNTIME_DIR}"
  prepare_dir "${OUTPUT_DIR}"

  info "Initialize easyrsa and pki structure."
  init_easyrsa "$arg_easyrsa_path"

  info "Done. Workspace is ready."
  info "EasyRSA: ${EASYRSA_DIR}"
  info "Runtime: ${RUNTIME_DIR}"
  info "Output:  ${OUTPUT_DIR}"
  info "SSL-PKI: ${EASYRSA_PKI}"
}

main "$@"