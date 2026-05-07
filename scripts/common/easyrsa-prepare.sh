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
  local pki_private_dir="${2:?PKI/private directory is required}"

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
  fi
}