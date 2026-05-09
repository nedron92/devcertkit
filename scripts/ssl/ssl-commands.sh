#!/usr/bin/env bash

# SSL subcommands for devcertkit
# This file is sourced by the main devcertkit script.

# Resolve the script directory of this file, independent of the caller.
SSL_COMMANDS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./ssl-pki.sh
source "${SSL_COMMANDS_SCRIPT_DIR}/ssl-pki.sh"

# -----------------------------
# General operation
# -----------------------------
show_ssl_help() {
  cat <<EOF
Usage: ./devcertkit ssl <command> [options]

Commands:
  init        Initialize SSL PKI structure and prepare CA
  help        Show this help message

Run './devcertkit ssl <command> --help' for more information on a command.
EOF
}

run_ssl_init() {
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
