#!/usr/bin/env bash

# This script implements the SSL subcommands for the devcertkit tool.
# It handles initializing the SSL PKI, managing the SSL CA, and
# dispatching certificate creation and inspection requests.
#
# This file is intended to be sourced by the main devcertkit script.

# Resolve the script directory of this file, independent of the caller.
SSL_COMMANDS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./ssl-pki.sh
source "${SSL_COMMANDS_SCRIPT_DIR}/ssl-pki.sh"

# -----------------------------
# Helpers
# -----------------------------
show_ssl_help() {
  # Displays the help message for the SSL subcommand.

  cat <<EOF
Usage: ./devcertkit ssl <command> [options]

Commands:
  init              Initialize SSL PKI structure and prepare CA
  ca create         Create a new SSL CA
  ca import         Import an existing SSL CA from config
  ca info           Display information about the SSL CA
  cert create       Create a new SSL certificate
  cert info         Display information about an existing certificate
  clean             Delete the SSL PKI directory
  help              Show this help message

Run './devcertkit ssl <command> --help' for more information on a command.
EOF
}

check_easyrsa_availability() {
  # Verifies that the EasyRSA binary is available and executable.
  # Fails with an error message if EasyRSA is missing.

  if [[ ! -x "${EASYRSA_BIN}" ]]; then
    warn "EasyRSA binary not found or not executable at ${EASYRSA_BIN}."
    fail "You need to initialize the devcertkit workspace first with 'devcertkit init'."
  fi
}

# -----------------------------
# General operation
# -----------------------------
run_ssl_init() {
  # Initializes the SSL PKI structure.
  # It sets up the PKI directories and either imports an existing CA
  # or prompts the user to create a new one.

  if [[ ! -x "${EASYRSA_BIN}" ]]; then
    warn "EasyRSA binary not found or not executable at ${EASYRSA_BIN}."
    echo -n "Do you want to initialize the devcertkit workspace now? (y/N): "
    if read -r response && [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      run_init
    else
      info "devcertkit init need to be run beforehand"
      return 0
    fi
  fi

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
      info "\nSkipping CA creation. You will need to provide CA files manually in ${SSL_CONFIG_DIR} and run 'devcertkit ssl init' again."
    fi
  fi
}

_run_ssl_ca_import() {
  # Imports an existing SSL CA into the PKI.
  check_easyrsa_availability
  import_ssl_ca
}

_run_ssl_ca_create() {
  # Internal function to create a new SSL CA.
  # It warns the user about overwriting existing files and performs a backup
  # of current CA files if they exist before proceeding with creation.

  check_easyrsa_availability

  warn "You are about to create a new CA. This will overwrite any existing CA files in the PKI and re-init it."
  echo -n "Are you sure you want to proceed? (y/N): "
  if read -r response && [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # Check if CA files already exist and offer backup
    if [[ -f "${SSL_CA_CRT}" || -f "${SSL_CA_KEY}" ]]; then
      warn "CA files already exist in ${SSL_CONFIG_DIR}."
      local timestamp
      timestamp=$(date +%Y%m%d_%H%M%S)
      local backup_dir="${SSL_CONFIG_DIR}/backup_${timestamp}"

      info "Creating backup in ${backup_dir}..."
      mkdir -p "${backup_dir}"
      [[ -f "${SSL_CA_CRT}" ]] && cp -p "${SSL_CA_CRT}" "${backup_dir}/"
      [[ -f "${SSL_CA_KEY}" ]] && cp -p "${SSL_CA_KEY}" "${backup_dir}/"
      info "Backup created."
    fi

    init_ssl_pki_structure "true"
    create_ssl_ca
  else
    info "CA creation aborted."
  fi
}

_run_ssl_ca_info() {
  # Displays information about the current SSL CA.
  # It uses the cert-info.sh script to read the CA certificate file.

  if [[ ! -f "${SSL_CA_CRT}" ]]; then
    fail "SSL CA certificate not found at ${SSL_CA_CRT}. Have you initialized the CA?"
  fi

  info "SSL CA Information"
  "${SSL_COMMANDS_SCRIPT_DIR}/cert-info.sh" --file "${SSL_CA_CRT}" "$@"
}

run_ssl_clean() {
  # Deletes the SSL PKI directory.
  clear_ssl_pki
}

# -----------------------------
# Main
# -----------------------------
run_ssl_commands() {
  # Main entry point for SSL subcommands.
  # Dispatches the command to the appropriate handler function.
  # Arguments:
  #   $1: SSL subcommand (init, ca, cert, help, etc.)
  #   $@: remaining arguments for the subcommand

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
    clean)
      run_ssl_clean "$@"
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
  # Dispatches SSL CA-related subcommands.
  # Arguments:
  #   $1: CA subcommand (create, import, info, etc.)
  #   $@: remaining arguments for the subcommand

  local subcmd="${1:-}"
  shift || true

  case "$subcmd" in
    create)
      _run_ssl_ca_create "$@"
      ;;
    import)
      _run_ssl_ca_import "$@"
      ;;
    info)
      _run_ssl_ca_info "$@"
      ;;
    -h|--help|help|"?")
      cat <<EOF
Usage: ./devcertkit ssl ca <command> [options]

Commands:
  create        Create a new SSL CA (interactively)
  import        Import an existing SSL CA from config/ca/ssl/
  info          Display information about the current SSL CA

Options:
  -h, --help    Show this help message
EOF
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
  # Dispatches SSL certificate-related subcommands.
  # Handles 'create' and 'info' by calling the respective scripts.
  # Arguments:
  #   $1: cert subcommand (create, info, etc.)
  #   $@: remaining arguments for the subcommand

  local subcmd="${1:-}"
  shift || true

  case "$subcmd" in
    create)
      check_easyrsa_availability
      "${SSL_COMMANDS_SCRIPT_DIR}/cert-create.sh" "$@"
      ;;
    info)
      "${SSL_COMMANDS_SCRIPT_DIR}/cert-info.sh" "$@"
      ;;
    -h|--help|help|"?")
      cat <<EOF
Usage: ./devcertkit ssl cert <command> [options]

Commands:
  create        Create a new SSL certificate signed by the CA
  info          Display information about an existing certificate

Run './devcertkit ssl cert <command> --help' for more information on a command.
EOF
      ;;
    *)
      if [[ -n "$subcmd" ]]; then
        warn "Unknown ssl cert subcommand: $subcmd"
      fi
      show_ssl_help
      ;;
  esac
}