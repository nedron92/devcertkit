find_easyrsa() {
  local user_path="${1:-}"

  if [[ -n "$user_path" ]]; then
    [[ -d "$user_path" ]] || fail "EasyRSA path does not exist: $user_path"
    [[ -x "$user_path/easyrsa" ]] || fail "No easyrsa binary found in: $user_path"
    echo "$user_path"
    return 0
  fi

  local candidate
  for candidate in \
    /usr/share/easy-rsa \
    /usr/share/easy-rsa3 \
    /usr/share/easyrsa
  do
    if [[ -x "$candidate/easyrsa" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}