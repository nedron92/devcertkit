resolve_easyrsa() {
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
  local pki_dir="${1:?PKI directory is required}"
  local pki_private_dir="${2:?PKI private directory is required}"

  if [[ -d "${pki_dir}" && -d "${pki_private_dir}" ]]; then
    info " EasyRSA PKI already exists: ${pki_dir}"
  else
    info "Initializing EasyRSA PKI in ${pki_dir}..."
    # Ensure directory is empty/clean for init-pki to avoid confirmation prompt
    rm -rf "${pki_dir}"
    # EasyRSA / OpenSSL compatibility seed file
    export EASYRSA_PKI="${pki_dir}"
    "${EASYRSA_BIN}" init-pki
    openssl rand -writerand "${pki_dir}/.rnd"
    
    # Copy correct vars file
    copy_ssl_vars "${pki_dir}"
  fi
}

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

prepare_ca() {
  local ca_dir="${1:?CA config directory is required}"
  local pki_dir="${2:?PKI directory is required}"
  local pki_private_dir="${3:?PKI private directory is required}"
  
  local ca_crt="${ca_dir}/ca.crt"
  local ca_key="${ca_dir}/ca.key"
  
  # Check if PKI is already initialized
  if [[ -f "${pki_dir}/ca.crt" && -f "${pki_private_dir}/ca.key" ]]; then
    info "CA already exists in PKI: ${pki_dir}"
    return 0
  fi

  if [[ -f "${ca_crt}" && -f "${ca_key}" ]]; then
    info "CA files found in ${ca_dir}. Importing..."
    
    # Run build-ca in batch mode to initialize the CA structure in PKI
    # We use 'nopass' but then overwrite the key anyway.
    export EASYRSA_BATCH=1
    "${EASYRSA_BIN}" build-ca nopass > /dev/null 2>&1
    
    # Overwrite the generated CA files with the ones from config
    cp -f "${ca_crt}" "${pki_dir}/ca.crt"
    cp -f "${ca_key}" "${pki_private_dir}/ca.key"
    copy_ssl_vars "${pki_dir}"
    
    info "CA files imported to PKI."
  else
    info "No CA files found in ${ca_dir}. Building new CA..."
    
    # Copy vars to pki folder before building
    copy_ssl_vars "${pki_dir}"
    
    export EASYRSA_BATCH=
    "${EASYRSA_BIN}" build-ca
    
    # Copy generated cert-files from pki folder to config/ca**
    info "Copying generated CA files to ${ca_dir}..."
    cp -f "${pki_dir}/ca.crt" "${ca_crt}"
    cp -f "${pki_private_dir}/ca.key" "${ca_key}"
    info "CA files copied to config."
  fi
}