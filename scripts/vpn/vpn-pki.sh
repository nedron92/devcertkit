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
    fail "No VPN vars file found. Expected either ${VPN_VARS_FILE} or ${VPN_VARS_FILE_DEFAULT}."
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

copy_vpn_ta_key() {
  # Imports the VPN TLS Auth key (ta.key) into the PKI.
  # EasyRSA 3.1+ provides 'import-tls-key' for this purpose.
  # It copies the key to 'pki/private/easyrsa-tls.key'.

  if [[ -f "${VPN_TA_KEY}" ]]; then
    local source_key="${VPN_TA_KEY}"
    local temp_key

    # EasyRSA might not recognize the standard OpenVPN static key header
    # for inline configuration generation. We ensure it has a header
    # that EasyRSA recognizes (TLS-AUTH or TLS-CRYPT).
    if grep -q "BEGIN OpenVPN Static key V1" "${source_key}" && ! grep -q "BEGIN TLS-AUTH" "${source_key}"; then
        info "Transforming TLS key header for EasyRSA compatibility..."
        temp_key=$(mktemp)
        echo "-----BEGIN TLS-AUTH-----" > "${temp_key}"
        grep -v "^#" "${source_key}" | grep -v "BEGIN OpenVPN Static key V1" | grep -v "END OpenVPN Static key V1" | sed '/^[[:space:]]*$/d' >> "${temp_key}"
        echo "-----END TLS-AUTH-----" >> "${temp_key}"
        source_key="${temp_key}"
    fi

    info "Importing VPN TLS key into PKI..."
    # We use EasyRSA's import-tls-key command.
    "${EASYRSA_BIN}" import-tls-key "${source_key}"

    # Cleanup temp key if created
    if [[ -n "${temp_key}" && -f "${temp_key}" ]]; then
        rm -f "${temp_key}"
    fi
  else
    warn "VPN TLS key (ta.key) not found at ${VPN_TA_KEY}."
  fi
}

generate_vpn_ta_key() {
  # Generates a new VPN TLS Auth key (ta.key) using OpenVPN.
  # It then copies the generated key to both the PKI and the configuration directory.

  info "Generating new VPN TLS Auth key..."
  
  prepare_dir "${VPN_PKI_DIR}/private"
  local tls_key="${VPN_PKI_DIR}/private/easyrsa-tls.key"

  openvpn --genkey --secret "${tls_key}"

  if [[ -f "${tls_key}" ]]; then
    info "Copying generated TLS key to ${VPN_TA_KEY}..."
    cp -f "${tls_key}" "${VPN_TA_KEY}"
    info "VPN TLS key generated and copied to config."
  else
    fail "Failed to generate VPN TLS key."
  fi
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
  copy_vpn_ta_key
  import_ca "${VPN_CONFIG_DIR}" "${VPN_PKI_DIR}" "${VPN_PKI_PRIVATE_DIR}"
}

create_vpn_ca() {
  # Creates a new VPN Certificate Authority and saves it to the configuration directory.
  # Arguments:
  #   $1: use password for CA (default: false)

  local use_pass="${1:-false}"
  local nopass="true"
  [[ "${use_pass}" == "true" ]] && nopass="false"

  copy_vpn_vars "${VPN_PKI_DIR}"
  copy_vpn_ta_key
  # Create VPN CA (default: without password)
  build_new_ca "${VPN_CONFIG_DIR}" "${VPN_PKI_DIR}" "${VPN_PKI_PRIVATE_DIR}" "${nopass}"
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
