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