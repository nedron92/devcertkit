#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./common/shared.sh
source "${SCRIPT_DIR}/common/shared.sh"
# shellcheck source=./common/paths.sh
source "${SCRIPT_DIR}/common/paths.sh"
# shellcheck source=./common/easyrsa-prepare.sh
source "${SCRIPT_DIR}/common/easyrsa-prepare.sh"

show_help() {
  cat <<EOF
Usage: ./${SCRIPT_NAME}

Initializes the devcertkit workspace and EasyRSA backend.

This command:
- prepares workspace directories
- initializes EasyRSA PKI for SSL
- does not create a CA certificate yet
EOF
}

prepare_dir() {
  mkdir -p "$1"
}

init_easyrsa() {
  if easyrsa_path="$(find_easyrsa "${EASYRSA_PATH:-}")"; then
    ln -sfn "$easyrsa_path" "${EASYRSA_DIR}"
  fi

  need_dir "${EASYRSA_DIR}"
  need_file "${EASYRSA_BIN}"

  prepare_dir "${EASYRSA_CONFIG_DIR}"
  prepare_dir "${SSL_OUTPUT_DIR}"

  export EASYRSA_PKI="${SSL_PKI_DIR}"

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
  case "${1:-}" in
    -h|--help)
      show_help
      exit 0
      ;;
  esac

  info "Initializing devcertkit workspace..."

  prepare_dir "${CONFIG_DIR}"
  prepare_dir "${RUNTIME_DIR}"
  prepare_dir "${OUTPUT_DIR}"

  init_easyrsa

  info "Workspace ready."
  info "EasyRSA: ${EASYRSA_DIR}"
  info "Config:  ${CONFIG_DIR}"
  info "Runtime: ${RUNTIME_DIR}"
  info "Output:  ${OUTPUT_DIR}"
  info "SSL-PKI: ${EASYRSA_PKI}"
}

main "$@"