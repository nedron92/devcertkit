#!/usr/bin/env bash

# SSL-specific EasyRSA helper functions for devcertkit.
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
  local pki_dir="${1:?PKI directory is required}"
  local vars_file
  vars_file="$(get_ssl_vars_file)"

  info "Using SSL vars file: ${vars_file}"
  cp -f "${vars_file}" "${pki_dir}/vars"
}

init_ssl_pki_structure() {
  # Initialize the EasyRSA PKI structure for SSL.
  local force="${1:-false}"
  init_pki_structure "${SSL_PKI_DIR}" "${SSL_PKI_PRIVATE_DIR}" "ssl" "${force}"
  copy_ssl_vars "${SSL_PKI_DIR}"
}

import_ssl_ca() {
  # Import an existing SSL CA from config/ca/ssl into the SSL PKI.
  # Useful when a pre-existing CA should be reused.
  copy_ssl_vars "${SSL_PKI_DIR}"
  import_ca "${SSL_CONFIG_DIR}" "${SSL_PKI_DIR}" "${SSL_PKI_PRIVATE_DIR}"
}

create_ssl_ca() {
  # Create a new SSL CA and persist it back to config/ca/ssl.
  copy_ssl_vars "${SSL_PKI_DIR}"
  build_new_ca "${SSL_CONFIG_DIR}" "${SSL_PKI_DIR}" "${SSL_PKI_PRIVATE_DIR}"
}

prepare_ssl_ca() {
  # Prepare SSL CA usage for certificate creation.
  copy_ssl_vars "${SSL_PKI_DIR}"
  prepare_ca "${SSL_CONFIG_DIR}" "${SSL_PKI_DIR}" "${SSL_PKI_PRIVATE_DIR}"
  copy_ssl_vars "${SSL_PKI_DIR}"
}