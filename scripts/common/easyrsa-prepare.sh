#!/usr/bin/env bash

# This script provides helper functions to prepare and manage EasyRSA PKI structures.
# It handles finding the EasyRSA binary, initializing PKI directories,
# and importing or building Certificate Authorities (CA).

resolve_easyrsa() {
  # Locates the EasyRSA installation directory.
  # If a path is provided, it verifies it. Otherwise, it checks common system paths.
  # Arguments:
  #   $1: optional user-provided path to EasyRSA
  # Returns:
  #   The absolute path to the EasyRSA directory.

  local user_path="${1:-}"
  if [[ -n "$user_path" ]]; then
    [[ -d "$user_path" ]] || fail "EasyRSA path does not exist: $user_path"
    [[ -x "$user_path/easyrsa" ]] || fail "No easyrsa binary found in: $user_path"
    echo "$user_path"
    return 0
  fi

  local system_path
  for system_path in \
    /usr/share/easy-rsa \
    /usr/share/easy-rsa3 \
    /usr/share/easyrsa
  do
    if [[ -x "$system_path/easyrsa" ]]; then
      echo "$system_path"
      return 0
    fi
  done

  fail "EasyRSA not found in system paths. Please provide --easyrsa-path <path>"
}

init_pki_structure() {
  # Initializes the EasyRSA PKI structure in the specified directory.
  # Arguments:
  #   $1: PKI directory
  #   $2: PKI private directory
  #   $3: PKI type (for logging)
  #   $4: force re-initialization (default: false)

  local pki_dir="${1:?PKI directory is required}"
  local pki_private_dir="${2:?PKI private directory is required}"
  local pki_type="${3:?PKI type is required}"
  local force="${4:-false}"

  if [[ "${force}" == "true" ]]; then
    info " Forcing re-initialization of EasyRSA PKI (${pki_type}) in ${pki_dir}..."
    rm -rf "${pki_dir}"
  fi

  if [[ -d "${pki_dir}" && -d "${pki_private_dir}" ]]; then
    info " EasyRSA PKI (${pki_type}) already exists: ${pki_dir}"
  else
    if [[ "${force}" != "true" ]]; then
      info "Initializing EasyRSA PKI (${pki_type}) in ${pki_dir}..."
    fi
    # Ensure directory is empty/clean for init-pki to avoid confirmation prompt
    rm -rf "${pki_dir}"
    # EasyRSA / OpenSSL compatibility seed file
    export EASYRSA_PKI="${pki_dir}"
    "${EASYRSA_BIN}" init-pki
    openssl rand -writerand "${pki_dir}/.rnd"
  fi
}

import_ca() {
  # Imports an existing CA certificate and key (from the config-directory) into the PKI structure.
  # Arguments:
  #   $1: CA source directory
  #   $2: PKI destination directory
  #   $3: PKI private destination directory

  local ca_dir="${1:?CA config directory is required}"
  local pki_dir="${2:?PKI directory is required}"
  local pki_private_dir="${3:?PKI private directory is required}"

  local ca_crt_src="${ca_dir}/ca.crt"
  local ca_key_src="${ca_dir}/ca.key"
  local ca_crt_dst="${pki_dir}/ca.crt"
  local ca_key_dst="${pki_private_dir}/ca.key"

  check_file "${ca_crt_src}"
  check_file "${ca_key_src}"

  if [[ -f "${ca_crt_dst}" || -f "${ca_key_dst}" ]]; then
    warn "CA files already exist in PKI. Overwriting..."
  fi

  info "Importing CA files from ${ca_dir}..."
  
  # Run build-ca in batch mode to initialize the CA structure in PKI
  # We use 'nopass' but then overwrite the key anyway.
  export EASYRSA_BATCH=1
  "${EASYRSA_BIN}" build-ca nopass > /dev/null 2>&1
  
  # Overwrite the generated CA files with the ones from config
  cp -f "${ca_crt_src}" "${ca_crt_dst}"
  cp -f "${ca_key_src}" "${ca_key_dst}"

  info "CA files imported to PKI."
}

build_new_ca() {
  # Builds a new Certificate Authority using EasyRSA.
  # The generated files are then copied back to the specified CA configuration directory.
  # Arguments:
  #   $1: CA config directory (to store the generated files)
  #   $2: PKI directory
  #   $3: PKI private directory

  local ca_dir="${1:?CA config directory is required}"
  local pki_dir="${2:?PKI directory is required}"
  local pki_private_dir="${3:?PKI private directory is required}"

  local ca_crt_dst="${ca_dir}/ca.crt"
  local ca_key_dst="${ca_dir}/ca.key"

  info "Building new CA..."
  
  export EASYRSA_BATCH=
  "${EASYRSA_BIN}" build-ca
  
  # Copy generated cert-files from pki folder to config/ca**
  info "Copying generated CA files to ${ca_dir}..."
  cp -f "${pki_dir}/ca.crt" "${ca_crt_dst}"
  cp -f "${pki_private_dir}/ca.key" "${ca_key_dst}"
  info "CA files copied to config."
}

prepare_ca() {
  # Orchestrates the CA preparation.
  # It checks if the CA already exists in the PKI. If not, it either imports
  # an existing CA from the config directory or builds a new one.
  # Arguments:
  #   $1: CA config directory
  #   $2: PKI directory
  #   $3: PKI private directory

  local ca_dir="${1:?CA config directory is required}"
  local pki_dir="${2:?PKI directory is required}"
  local pki_private_dir="${3:?PKI private directory is required}"
  
  local ca_crt="${ca_dir}/ca.crt"
  local ca_key="${ca_dir}/ca.key"
  
  # Check if CA-files in PKI already exists
  if [[ -f "${pki_dir}/ca.crt" && -f "${pki_private_dir}/ca.key" ]]; then
    info "CA already exists in PKI: ${pki_dir}"
    return 0
  fi

  if [[ -f "${ca_crt}" && -f "${ca_key}" ]]; then
    import_ca "${ca_dir}" "${pki_dir}" "${pki_private_dir}"
  else
    build_new_ca "${ca_dir}" "${pki_dir}" "${pki_private_dir}"
  fi
}