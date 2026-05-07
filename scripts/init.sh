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

  if [[ -x "${EASYRSA_BIN}" ]]; then
    info " EasyRSA binary already exists at ${EASYRSA_BIN}, skipping resolution."
  else
    info "Resolving EasyRSA..."
    easyrsa_path_found="$(resolve_easyrsa "$easyrsa_path")"
    ln -sfn "$easyrsa_path_found" "${EASYRSA_DIR}"
  fi

  prepare_dir "${SSL_OUTPUT_DIR}"

  init_pki_structure "${SSL_PKI_DIR}" "${SSL_PKI_PRIVATE_DIR}"
  prepare_ca "${SSL_CONFIG_DIR}" "${SSL_PKI_DIR}" "${SSL_PKI_PRIVATE_DIR}"
}

run_init() {
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
          fail " --easyrsa-path requires an argument."
        fi
        ;;
      *)
        fail " Unknown argument: $1"
        ;;
    esac
  done

  info "Initializing devcertkit workspace..."

  if [[ ! -d "${RUNTIME_DIR}" ]]; then
    info " Preparing runtime directory: ${RUNTIME_DIR}"
    prepare_dir "${RUNTIME_DIR}"
  fi

  if [[ ! -d "${OUTPUT_DIR}" ]]; then
    info " Preparing output directory: ${OUTPUT_DIR}"
    prepare_dir "${OUTPUT_DIR}"
  fi

  info "\nInitialize easyrsa and pki structure."
  init_easyrsa "$user_easyrsa_path"

  info "\nDone. Workspace is ready."
  info "  EasyRSA: ${EASYRSA_DIR}"
  info "  Runtime: ${RUNTIME_DIR}"
  info "  Output:  ${OUTPUT_DIR}"
  info "  SSL-PKI: ${SSL_PKI_DIR}"
}

run_init "$@"