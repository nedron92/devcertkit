#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=./common/shared.sh
source "${SCRIPT_DIR}/common/shared.sh"

BACKEND_DIR="${ROOT_DIR}/backend/.easyrsa"
EASYRSA_BIN="${BACKEND_DIR}/easyrsa"

CONFIG_DIR="${ROOT_DIR}/config"
RUNTIME_DIR="${ROOT_DIR}/runtime"
OUTPUT_DIR="${ROOT_DIR}/output"

EASYRSA_CONFIG_DIR="${CONFIG_DIR}/easyrsa"
SSL_RUNTIME_DIR="${RUNTIME_DIR}/ssl/pki"
SSL_OUTPUT_DIR="${OUTPUT_DIR}/certs"

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
  # shellcheck source=./common/shared.sh
  source "${SCRIPT_DIR}/common/easyrsa-init.sh"

  if easyrsa_path="$(find_easyrsa "${EASYRSA_PATH:-}")"; then
    ln -sfn "$easyrsa_path" "${ROOT_DIR}/backend/.easyrsa"
  fi

  need_dir "${BACKEND_DIR}"
  need_file "${EASYRSA_BIN}"

  prepare_dir "${SSL_RUNTIME_DIR}"
  prepare_dir "${EASYRSA_CONFIG_DIR}"
  prepare_dir "${SSL_OUTPUT_DIR}"

  # EasyRSA / OpenSSL compatibility seed file
  openssl rand -writerand "${SSL_RUNTIME_DIR}/.rnd"

  export EASYRSA_PKI="${SSL_RUNTIME_DIR}"

  if [[ ! -d "${SSL_RUNTIME_DIR}/private" ]]; then
    info "Initializing EasyRSA PKI..."
    "${EASYRSA_BIN}" init-pki
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
  info "Backend: ${BACKEND_DIR}"
  info "Config:  ${CONFIG_DIR}"
  info "Runtime: ${RUNTIME_DIR}"
  info "Output:  ${OUTPUT_DIR}"
  info "EasyRSA: ${EASYRSA_PKI}"
}

main "$@"