#!/usr/bin/env bash

# This script implements the VPN subcommands for the devcertkit tool.
# It handles initializing the VPN PKI, managing the VPN CA, and
# dispatching client configuration and certificate creation.
#
# This file is intended to be sourced by the main devcertkit script.

# Resolve the script directory of this file, independent of the caller.
VPN_COMMANDS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./vpn-pki.sh
source "${VPN_COMMANDS_SCRIPT_DIR}/vpn-pki.sh"

# -----------------------------
# Helpers
# -----------------------------
show_vpn_help() {
  # Displays the help message for the VPN subcommand.

  cat <<EOF
Usage: ./devcertkit vpn <command> [options]

Commands:
  init              Initialize VPN PKI structure and prepare CA.
  ca create         Create a new VPN CA (default: without password).
                    Options: --pass  Create CA with a password.
  ca import         Import an existing VPN CA from config/ca/vpn/.
  ca info           Display information about the VPN CA.
  ca gen-tls        Generate OpenVPN TLS-AUTH key (ta.key).
  client create     Create a new VPN client with config and certificates.
  client info       Display information about an existing VPN client.
  clean             Delete the VPN PKI directory.
  help              Show this help message.

Run './devcertkit vpn <command> help' for more information on a command.
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

check_vpn_dependencies() {
  # Checks for dependencies required specifically for VPN operations.
  check_easyrsa_availability
  need_cmd "openvpn"
}

# -----------------------------
# General operation
# -----------------------------
run_vpn_init() {
  # Initializes the VPN PKI structure.
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

  info "Initializing VPN PKI structure..."
  init_vpn_pki_structure

  if [[ -f "${VPN_CA_CRT}" && -f "${VPN_CA_KEY}" ]]; then
    info "CA files found in ${VPN_CONFIG_DIR}. Importing..."
    import_vpn_ca
  else
    warn "No CA files found in ${VPN_CONFIG_DIR}."
    echo -n "Do you want to create a new CA? (y/N): "
    if read -r response && [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      create_vpn_ca
    else
      info "\nSkipping CA creation. You will need to provide CA files manually in ${VPN_CONFIG_DIR} and run 'devcertkit vpn init' again."
    fi
  fi

  if [[ ! -f "${VPN_TA_KEY}" ]]; then
    warn "VPN TLS key (ta.key) is missing."
    echo -n "Do you want to generate a new ta.key? (y/N): "
    if read -r response && [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      generate_vpn_ta_key
    else
      info "Skipping ta.key generation. You will need to provide it manually."
    fi
  fi
}

_run_vpn_ca_import() {
  # Imports an existing VPN CA into the PKI.
  check_vpn_dependencies
  import_vpn_ca
}

_run_vpn_ca_create() {
  # Internal function to create a new VPN CA.
  # It warns the user about overwriting existing files and performs a backup
  # of current CA files if they exist before proceeding with creation.
  # Arguments:
  #   $1: optional --pass flag

  local use_pass="false"
  if [[ "${1:-}" == "--pass" ]]; then
    use_pass="true"
  fi

  check_vpn_dependencies

  warn "You are about to create a new CA. This will overwrite any existing CA files in the PKI and re-init it."
  echo -n "Are you sure you want to proceed? (y/N): "
  if read -r response && [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # Check if CA files already exist and offer backup
    if [[ -f "${VPN_CA_CRT}" || -f "${VPN_CA_KEY}" ]]; then
      warn "CA files already exist in ${VPN_CONFIG_DIR}."
      local timestamp
      timestamp=$(date +%Y%m%d_%H%M%S)
      local backup_dir="${VPN_CONFIG_DIR}/backup_${timestamp}"

      info "Creating backup in ${backup_dir}..."
      mkdir -p "${backup_dir}"
      [[ -f "${VPN_CA_CRT}" ]] && cp -p "${VPN_CA_CRT}" "${backup_dir}/"
      [[ -f "${VPN_CA_KEY}" ]] && cp -p "${VPN_CA_KEY}" "${backup_dir}/"
      info "Backup created."
    fi

    init_vpn_pki_structure "true"
    create_vpn_ca "${use_pass}"

    if [[ ! -f "${VPN_TA_KEY}" ]]; then
      warn "VPN TLS key (ta.key) is missing."
      echo -n "Do you want to generate a new ta.key? (y/N): "
      if read -r response && [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        generate_vpn_ta_key
      else
        info "Skipping ta.key generation. You will need to provide it manually."
      fi
    fi
  else
    info "CA creation aborted."
  fi
}

_run_vpn_ca_info() {
  # Displays information about the current VPN CA.
  # It uses the cert-info.sh script (from SSL, but generic) to read the CA certificate file.

  if [[ ! -f "${VPN_CA_CRT}" ]]; then
    fail "VPN CA certificate not found at ${VPN_CA_CRT}. Have you initialized the CA?"
  fi

  info "VPN CA Information"
  # Using the existing cert-info.sh from common directory
  "${VPN_COMMANDS_SCRIPT_DIR}/../common/cert-info.sh" --file "${VPN_CA_CRT}" "$@"
}

_run_vpn_gen_tls_key() {
  # Generates a new VPN TLS-AUTH key.
  check_vpn_dependencies
  generate_vpn_ta_key
}

run_vpn_clean() {
  # Deletes the VPN PKI directory.
  clear_vpn_pki
}

# -----------------------------
# Main
# -----------------------------
run_vpn_commands() {
  # Main entry point for VPN subcommands.
  # Dispatches the command to the appropriate handler function.
  # Arguments:
  #   $1: VPN subcommand (init, ca, client, help, etc.)
  #   $@: remaining arguments for the subcommand

  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    init)
      run_vpn_init "$@"
      ;;
    ca)
      run_vpn_ca_commands "$@"
      ;;
    client)
      run_vpn_client_commands "$@"
      ;;
    clean)
      run_vpn_clean "$@"
      ;;
    -h|--help|help|"?")
      show_vpn_help
      ;;
    *)
      if [[ -n "$cmd" ]]; then
        warn "Unknown vpn subcommand: $cmd"
      fi
      show_vpn_help
      ;;
  esac
}

run_vpn_ca_commands() {
  # Dispatches VPN CA-related subcommands.
  # Arguments:
  #   $1: CA subcommand (create, import, info, etc.)
  #   $@: remaining arguments for the subcommand

  local subcmd="${1:-}"
  shift || true

  case "$subcmd" in
    create)
      _run_vpn_ca_create "$@"
      ;;
    import)
      _run_vpn_ca_import "$@"
      ;;
    info)
      _run_vpn_ca_info "$@"
      ;;
    gen-tls)
      _run_vpn_gen_tls_key "$@"
      ;;
    -h|--help|help|"?")
      cat <<EOF
Usage: ./devcertkit vpn ca <command> [options]

Commands:
  create        Create a new VPN CA (interactively)
  import        Import an existing VPN CA from config/ca/vpn/
  info          Display information about the current VPN CA
  gen-tls       Generate OpenVPN TLS-AUTH key (ta.key)

Options:
  -h, --help    Show this help message
EOF
      ;;
    *)
      if [[ -n "$subcmd" ]]; then
        warn "Unknown vpn ca subcommand: $subcmd"
      fi
      show_vpn_help
      ;;
  esac
}

run_vpn_client_commands() {
  # Dispatches VPN client-related subcommands.
  # Handles 'create' by calling the respective scripts.
  # Arguments:
  #   $1: client subcommand (create, etc.)
  #   $@: remaining arguments for the subcommand

  local subcmd="${1:-}"
  shift || true

  case "$subcmd" in
    create)
      check_easyrsa_availability
      "${VPN_COMMANDS_SCRIPT_DIR}/client-create.sh" "$@"
      ;;
    -h|--help|help|"?")
      cat <<EOF
Usage: ./devcertkit vpn client <command> [options]

Commands:
  create        Create a new VPN client with config-file and certificates
  info          Display information about an existing VPN client certificate

Run './devcertkit vpn client <command> --help' for more information on a command.
EOF
      ;;
    info)
      "${VPN_COMMANDS_SCRIPT_DIR}/../common/cert-info.sh" "$@"
      ;;
    *)
      if [[ -n "$subcmd" ]]; then
        warn "Unknown vpn client subcommand: $subcmd"
      fi
      show_vpn_help
      ;;
  esac
}
