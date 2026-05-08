#!/usr/bin/env bash

# shellcheck source=../common/paths.sh
source "${SCRIPT_DIR}/../common/paths.sh"
export EASYRSA_PKI="${SSL_PKI_DIR}"

# shellcheck source=../common/easyrsa-prepare.sh
source "${SCRIPT_DIR}/../common/easyrsa-prepare.sh"

get_ssl_vars_file() {
  if [[ -f "${SSL_VARS_FILE}" ]]; then
    echo "${SSL_VARS_FILE}"
  else
    echo "${SSL_VARS_FILE_DEFAULT}"
  fi
}

copy_ssl_vars() {
  local pki_dir="${1:?PKI directory is required}"
  local vars_file
  vars_file=$(get_ssl_vars_file)
  
  info "Using vars-file: ${vars_file}"
  cp -f "${vars_file}" "${pki_dir}/vars"
}

init_ssl_pki_structure() {
  init_pki_structure "${SSL_PKI_DIR}" "${SSL_PKI_PRIVATE_DIR}" "ssl"
  copy_ssl_vars "${SSL_PKI_DIR}"
}

prepare_ssl_ca() {
  copy_ssl_vars "${SSL_PKI_DIR}"
  prepare_ca "${SSL_CONFIG_DIR}" "${SSL_PKI_DIR}" "${SSL_PKI_PRIVATE_DIR}"
  copy_ssl_vars "${SSL_PKI_DIR}"
}