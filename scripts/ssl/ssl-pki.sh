#!/usr/bin/env bash

# This script provides SSL-specific helper functions for managing EasyRSA PKI.
# It handles PKI initialization, CA management, and configuration variable
# handling specifically for SSL certificates.
#
# This file is intended to be sourced by SSL commands and the root wrapper.
# It only provides helpers; it does not implement CLI parsing.

# Resolve the script directory of this file, independent of the caller.
SSL_INIT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../common/shared.sh
source "${SSL_INIT_SCRIPT_DIR}/../common/shared.sh"
# shellcheck source=../common/paths.sh
source "${SSL_INIT_SCRIPT_DIR}/../common/paths.sh"
# shellcheck source=../common/easyrsa-prepare.sh
source "${SSL_INIT_SCRIPT_DIR}/../common/easyrsa-prepare.sh"

# Keep the SSL PKI location explicit for all SSL helpers.
export EASYRSA_PKI="${SSL_PKI_DIR}"

get_ssl_vars_file() {
  # Determines the correct EasyRSA vars file to use for SSL operations.
  # It prioritizes the custom SSL vars file over the default one.
  # Returns:
  #   The path to the determined vars file.

  local vars_file
  if [[ -f "${SSL_VARS_FILE}" ]]; then
    vars_file="${SSL_VARS_FILE}"
  elif [[ -f "${SSL_VARS_FILE_DEFAULT}" ]]; then
    vars_file="${SSL_VARS_FILE_DEFAULT}"
  else
    fail "No SSL vars file found. Expected either ${SSL_VARS_FILE} or ${SSL_VARS_FILE_DEFAULT}."
  fi

  echo "${vars_file}"
}

copy_ssl_vars() {
  # Copies the appropriate SSL vars file to the specified PKI directory.
  # Arguments:
  #   $1: PKI directory where the vars file should be copied

  local pki_dir="${1:?PKI directory is required}"
  local vars_file
  vars_file="$(get_ssl_vars_file)"

  info "Using SSL vars file: ${vars_file}"
  cp -f "${vars_file}" "${pki_dir}/vars"
}

init_ssl_pki_structure() {
  # Initializes the EasyRSA PKI structure for SSL.
  # It sets up the directory structure and copies the SSL vars file.
  # Arguments:
  #   $1: force re-initialization (default: false)

  local force="${1:-false}"
  init_pki_structure "${SSL_PKI_DIR}" "${SSL_PKI_PRIVATE_DIR}" "ssl" "${force}"
  copy_ssl_vars "${SSL_PKI_DIR}"
}

import_ssl_ca() {
  # Imports an existing SSL CA from the configuration directory into the SSL PKI.
  # This is used when you want to reuse a pre-existing CA.

  local pki_ca_crt="${SSL_PKI_DIR}/ca.crt"
  local pki_ca_key="${SSL_PKI_PRIVATE_DIR}/ca.key"

  if [[ -f "${pki_ca_crt}" || -f "${pki_ca_key}" ]]; then
    warn "CA files already exist in the SSL PKI."
    echo -n "Are you sure you want to overwrite the existing PKI CA? (y/N): "
    if ! (read -r response && [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]); then
      info "Import aborted."
      return 1
    fi
  fi

  copy_ssl_vars "${SSL_PKI_DIR}"
  import_ca "${SSL_CONFIG_DIR}" "${SSL_PKI_DIR}" "${SSL_PKI_PRIVATE_DIR}"
}

create_ssl_ca() {
  # Creates a new SSL Certificate Authority and saves it to the configuration directory.

  copy_ssl_vars "${SSL_PKI_DIR}"
  build_new_ca "${SSL_CONFIG_DIR}" "${SSL_PKI_DIR}" "${SSL_PKI_PRIVATE_DIR}"
}

prepare_ssl_ca() {
  # Orchestrates the preparation of the SSL CA.
  # It ensures that the CA exists in the PKI, either by importing it
  # or creating a new one if it doesn't exist.

  copy_ssl_vars "${SSL_PKI_DIR}"
  prepare_ca "${SSL_CONFIG_DIR}" "${SSL_PKI_DIR}" "${SSL_PKI_PRIVATE_DIR}"
  copy_ssl_vars "${SSL_PKI_DIR}"
}

clear_ssl_pki() {
  # Deletes the entire SSL PKI directory.
  # This effectively resets the SSL PKI state.

  if [[ -d "${SSL_PKI_DIR}" ]]; then
    info "Deleting SSL PKI directory: ${SSL_PKI_DIR}"
    rm -rf "${SSL_PKI_DIR}"
    info "SSL PKI directory deleted."
  else
    info "SSL PKI directory does not exist: ${SSL_PKI_DIR}"
  fi
}
