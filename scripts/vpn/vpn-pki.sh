#!/usr/bin/env bash

# This script provides VPN-specific helper functions for managing EasyRSA PKI.
# It handles PKI initialization, CA management, and configuration variable
# handling specifically for VPN certificates / configurations.
#
# This file is intended to be sourced by VPN commands and the root wrapper.
# It only provides helpers; it does not implement CLI parsing.

# Resolve the script directory of this file, independent of the caller.
VPN_INIT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../common/shared.sh
source "${VPN_INIT_SCRIPT_DIR}/../common/shared.sh"
# shellcheck source=../common/paths.sh
source "${VPN_INIT_SCRIPT_DIR}/../common/paths.sh"
# shellcheck source=../common/easyrsa-prepare.sh
source "${VPN_INIT_SCRIPT_DIR}/../common/easyrsa-prepare.sh"

# Keep the VPN PKI location explicit for all VPN helpers.
export EASYRSA_PKI="${VPN_PKI_DIR}"

get_vpn_vars_file() {
  # Determines the correct EasyRSA vars file to use for VPN operations.
  # It prioritizes the custom VPN vars file over the default one.
  # Returns:
  #   The path to the determined vars file.

  local vars_file
  if [[ -f "${VPN_VARS_FILE}" ]]; then
    vars_file="${VPN_VARS_FILE}"
  elif [[ -f "${VPN_VARS_FILE_DEFAULT}" ]]; then
    vars_file="${VPN_VARS_FILE_DEFAULT}"
  else
    fail "No SSL vars file found. Expected either ${VPN_VARS_FILE} or ${VPN_VARS_FILE_DEFAULT}."
  fi

  echo "${vars_file}"
}

copy_vpn_vars() {
  # Copies the appropriate SSL vars file to the specified PKI directory.
  # Arguments:
  #   $1: PKI directory where the vars file should be copied

  local pki_dir="${1:?PKI directory is required}"
  local vars_file
  vars_file="$(get_vpn_vars_file)"

  info "Using VPN vars file: ${vars_file}"
  cp -f "${vars_file}" "${pki_dir}/vars"
}

init_vpn_pki_structure() {
  # Initializes the EasyRSA PKI structure for VPN.
  # It sets up the directory structure and copies the VPN vars file.
  # Arguments:
  #   $1: force re-initialization (default: false)

  local force="${1:-false}"
  init_pki_structure "${VPN_PKI_DIR}" "${VPN_PKI_PRIVATE_DIR}" "vpn" "${force}"
  copy_vpn_vars "${VPN_PKI_DIR}"
}

import_vpn_ca() {
  # Imports an existing VPN CA from the configuration directory into the VPN PKI.
  # This is used when you want to reuse a pre-existing CA.

  local pki_ca_crt="${VPN_PKI_DIR}/ca.crt"
  local pki_ca_key="${VPN_PKI_PRIVATE_DIR}/ca.key"

  if [[ -f "${pki_ca_crt}" || -f "${pki_ca_key}" ]]; then
    warn "CA files already exist in the VPN PKI."
    echo -n "Are you sure you want to overwrite the existing PKI CA? (y/N): "
    if ! (read -r response && [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]); then
      info "Import aborted."
      return 1
    fi
  fi

  copy_vpn_vars "${VPN_PKI_DIR}"
  import_ca "${VPN_CONFIG_DIR}" "${VPN_PKI_DIR}" "${VPN_PKI_PRIVATE_DIR}"
}

create_vpn_ca() {
  # Creates a new VPN Certificate Authority and saves it to the configuration directory.

  copy_vpn_vars "${VPN_PKI_DIR}"
  build_new_ca "${VPN_CONFIG_DIR}" "${VPN_PKI_DIR}" "${VPN_PKI_PRIVATE_DIR}"
}

prepare_vpn_ca() {
  # Orchestrates the preparation of the VPN CA.
  # It ensures that the CA exists in the PKI, either by importing it
  # or creating a new one if it doesn't exist.

  copy_vpn_vars "${VPN_PKI_DIR}"
  prepare_ca "${VPN_CONFIG_DIR}" "${VPN_PKI_DIR}" "${VPN_PKI_PRIVATE_DIR}"
  copy_vpn_vars "${VPN_PKI_DIR}"
}

clear_vpn_pki() {
  # Deletes the entire VPN PKI directory.
  # This effectively resets the VPN PKI state.

  if [[ -d "${VPN_PKI_DIR}" ]]; then
    info "Deleting VPN PKI directory: ${VPN_PKI_DIR}"
    rm -rf "${VPN_PKI_DIR}"
    info "VPN PKI directory deleted."
  else
    info "VPN PKI directory does not exist: ${VPN_PKI_DIR}"
  fi
}
