#!/usr/bin/env bash

# SSL subcommands for devcertkit
# This file is sourced by the main devcertkit script.

# Resolve the script directory of this file, independent of the caller.
SSL_COMMANDS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./ssl-pki.sh
source "${SSL_COMMANDS_SCRIPT_DIR}/ssl-pki.sh"

# -----------------------------
# Helpers
# -----------------------------
show_ssl_help() {
  cat <<EOF
Usage: ./devcertkit ssl <command> [options]

Commands:
  init          Initialize SSL PKI structure and prepare CA
  ca create     Create a new SSL CA
  cert create   Create a new SSL certificate
  help          Show this help message

Run './devcertkit ssl <command> --help' for more information on a command.
EOF
}

check_easyrsa_availability() {
  if [[ ! -x "${EASYRSA_DIR}/easyrsa" ]]; then
    warn "EasyRSA binary not found or not executable at ${EASYRSA_DIR}/easyrsa."
    fail "You need to initialize the devcertkit workspace first with 'devcertkit init'."
  fi
}

# -----------------------------
# General operation
# -----------------------------
run_ssl_init() {
  check_easyrsa_availability
  info "Initializing SSL PKI structure..."
  init_ssl_pki_structure

  if [[ -f "${SSL_CA_CRT}" && -f "${SSL_CA_KEY}" ]]; then
    info "CA files found in ${SSL_CONFIG_DIR}. Importing..."
    import_ssl_ca
  else
    warn "No CA files found in ${SSL_CONFIG_DIR}."
    echo -n "Do you want to create a new CA? (y/N): "
    if read -r response && [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      create_ssl_ca
    else
      info "\nSkipping CA creation. You will need to provide CA files manually in ${SSL_CONFIG_DIR} and run 'ssl init' again."
    fi
  fi
}

# -----------------------------
# Main
# -----------------------------
run_ssl_commands() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    init)
      run_ssl_init "$@"
      ;;
    ca)
      run_ssl_ca_commands "$@"
      ;;
    cert)
      run_ssl_cert_commands "$@"
      ;;
    -h|--help|help|"?")
      show_ssl_help
      ;;
    *)
      if [[ -n "$cmd" ]]; then
        warn "Unknown ssl subcommand: $cmd"
      fi
      show_ssl_help
      ;;
  esac
}

run_ssl_ca_commands() {
  local subcmd="${1:-}"
  shift || true

  case "$subcmd" in
    create)
      check_easyrsa_availability
      warn "You are about to create a new CA. This will overwrite any existing CA files in the PKI."
      echo -n "Are you sure you want to proceed? (y/N): "
      if read -r response && [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        create_ssl_ca
      else
        info "CA creation aborted."
      fi
      ;;
    *)
      if [[ -n "$subcmd" ]]; then
        warn "Unknown ssl ca subcommand: $subcmd"
      fi
      show_ssl_help
      ;;
  esac
}

run_ssl_cert_commands() {
  local subcmd="${1:-}"
  shift || true

  case "$subcmd" in
    create)
      check_easyrsa_availability
      "${SSL_COMMANDS_SCRIPT_DIR}/create-cert.sh" "$@"
      ;;
    *)
      if [[ -n "$subcmd" ]]; then
        warn "Unknown ssl cert subcommand: $subcmd"
      fi
      show_ssl_help
      ;;
  esac
}