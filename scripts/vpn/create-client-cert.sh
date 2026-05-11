#!/usr/bin/env bash
set -Eeuo pipefail

# -----------------------------
# Config
# -----------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/paths.sh
source "${SCRIPT_DIR}/../common/paths.sh"
# shellcheck source=../common/shared.sh
source "${SCRIPT_DIR}/../common/shared.sh"
# shellcheck source=../common/easyrsa-prepare.sh
source "${SCRIPT_DIR}/../common/easyrsa-prepare.sh"

SCRIPT_NAME="$(basename "$0")"

VPN_CONFIG_FILE="${CONFIG_DIR}/vpn.settings"
check_file "$VPN_CONFIG_FILE"
# shellcheck source=/dev/null
source "$VPN_CONFIG_FILE"

# Vars from paths.sh:
# EASYRSA_BIN
# VPN_CONFIG_DIR (formerly EXISTING_CA_DIR)
# VPN_PKI_DIR (formerly PKI_DIR)
# VPN_PKI_PRIVATE_DIR (formerly PKI_PRIVATE_DIR)
# VPN_OUTPUT_DIR (formerly CLIENT_DIR)

VARS_FILE="${EASYRSA_CONFIG_DIR}/vars.vpn.default"

CLEAN_ONLY="false"
TYPE="general"  	# set type (general | mobile | router), DEFAULT: general
ARCHIVE="true"   	# if false -> skip 7z
NO_PASS="false"  	# if true, create cert without a password

# -----------------------------
# Helpers
# -----------------------------

get_active_vpn_host() {
  local host
  for host in "${VPN_HOSTS[@]}"; do
    [[ "$host" =~ ^# ]] && continue
    echo "$host"
    return 0
  done

  fail "No active VPN host configured."
}


patch_ovpn_client_placeholders() {
  # Replace client-related placeholders in OpenVPN config templates.
  #
  # Supported placeholders:
  #   __CLIENT__ 	-> client name
  #   __VPN_HOST__ 	-> VPN server host
  #   __VPN_PORT__ 	-> VPN server port

  local config_file="$1"
  local client_name="$2"
  local vpn_host="$3"
  local vpn_port="$4"
  local vpn_port_fallback="$5"

  check_file "$config_file"

  sed -i \
    -e "s|__CLIENT__|${client_name}|g" \
    -e "s|__VPN_HOST__|${vpn_host}|g" \
    -e "s|__VPN_PORT__|${vpn_port}|g" \
	  -e "s|__VPN_PORT_FALLBACK__|${vpn_port_fallback}|g" \
    "$config_file"
}

show_help() {
  cat <<EOF
Usage:
  ./${SCRIPT_NAME} [OPTIONS] clientName

Options:
  -t, --type <type>      Client type: general | mobile | router (default: general)
      --no-pass          Create client certificate without a password.
      --no-archive       Do not create a 7z archive.
      --vpn-port <port>  VPN server port used in client config (default: 1194)
      --clean            Delete PKI directory and exit.
  -h, --help             Show this help message.

Examples:
  # General client with password
  ./${SCRIPT_NAME} ovpn-connector-xxx

  # Router client without password
  ./${SCRIPT_NAME} -t router --no-pass router-xxx
EOF
}

# -----------------------------
# Argument parsing
# -----------------------------
CLIENT_NAME=""
VPN_HOST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--type)
      [[ -n "${2:-}" ]] || fail "Missing value for $1"
      TYPE="$2"
      shift 2
      ;;
    --no-pass)
      NO_PASS="true"
      shift
      ;;
    --no-archive)
      ARCHIVE="false"
      shift
      ;;
    --vpn-port)
      [[ -n "${2:-}" ]] || fail "Missing value for --vpn-port"
      VPN_PORT="$2"
      shift 2
      ;;
    --clean)
      CLEAN_ONLY="true"
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      CLIENT_NAME="$1"
      VPN_HOST="$(get_active_vpn_host)"
      shift
      ;;
  esac
done

[[ -n "$CLIENT_NAME" || "$CLEAN_ONLY" == "true" ]] || fail "Missing client name."

# -----------------------------
# Clean
# -----------------------------
if [[ "$CLEAN_ONLY" == "true" ]]; then
  rm -rf "$VPN_PKI_DIR"
  info "Deleted PKI directory: $VPN_PKI_DIR"
  exit 0
fi

# -----------------------------
# Validation
# -----------------------------
case "$TYPE" in
  general|mobile|router) ;;
  *) fail "Invalid type: $TYPE (allowed: general, mobile, router)" ;;
esac

check_file "$EASYRSA_BIN"
check_dir "$VPN_CONFIG_DIR"
check_file "$VPN_CA_CRT"
check_file "$VPN_CA_KEY"
check_file "${VPN_CONFIG_DIR}/ta.key"
check_file "$VARS_FILE"

prepare_dir "$VPN_OUTPUT_DIR/$CLIENT_NAME"

# -----------------------------
# PKI init & CA import
# -----------------------------
export EASYRSA_PKI="$VPN_PKI_DIR"
init_pki_structure "$VPN_PKI_DIR" "$VPN_PKI_PRIVATE_DIR" "VPN"
prepare_ca "$VPN_CONFIG_DIR" "$VPN_PKI_DIR" "$VPN_PKI_PRIVATE_DIR"

# Ensure vars file is used
cp -f "$VARS_FILE" "$VPN_PKI_DIR/vars"

# -----------------------------
# Client cert creation
# -----------------------------
info "Creating OpenVPN client certificate:"
info "  Name: $CLIENT_NAME"
info "  Type: $TYPE"
info "  Password: $([[ "$NO_PASS" == "true" ]] && echo "no" || echo "yes")"
info "  VPN-Config: "
info "    Host: $VPN_HOST"
info "    Port, default: $VPN_PORT"
info "    Port, fallback: $VPN_PORT_FALLBACK"

if [[ "$NO_PASS" == "true" ]]; then
  "$EASYRSA_BIN" gen-req "$CLIENT_NAME" nopass
else
  "$EASYRSA_BIN" gen-req "$CLIENT_NAME"
fi

"$EASYRSA_BIN" sign-req client "$CLIENT_NAME"

# -----------------------------
# Copy files
# -----------------------------
cp -f "$VPN_PKI_DIR/issued/$CLIENT_NAME.crt" "$VPN_OUTPUT_DIR/$CLIENT_NAME/"
cp -f "$VPN_PKI_DIR/private/$CLIENT_NAME.key" "$VPN_OUTPUT_DIR/$CLIENT_NAME/"
cp -f "$VPN_PKI_DIR/ca.crt" "$VPN_OUTPUT_DIR/$CLIENT_NAME/"
cp -f "${VPN_CONFIG_DIR}/ta.key" "$VPN_OUTPUT_DIR/$CLIENT_NAME/"

# -----------------------------
# Client config template
# -----------------------------
cfg=""
TEMPLATE_DIR="${CONFIG_DIR}/templates/vpn/client"

case "$TYPE" in
  general)
    cfg="$VPN_OUTPUT_DIR/$CLIENT_NAME/$CLIENT_NAME-default.ovpn"
	cfg2="$VPN_OUTPUT_DIR/$CLIENT_NAME/$CLIENT_NAME-fallback.ovpn"
    cp "${TEMPLATE_DIR}/ovpn-general-client-default.ovpn" "$cfg"
	cp "${TEMPLATE_DIR}/ovpn-general-client-fallback.ovpn" "$cfg2"
	patch_ovpn_client_placeholders "$cfg2" "$CLIENT_NAME" "$VPN_HOST" "$VPN_PORT" "$VPN_PORT_FALLBACK"
    ;;
  mobile)
    cfg="$VPN_OUTPUT_DIR/$CLIENT_NAME/$CLIENT_NAME.ovpn"
    cp "${TEMPLATE_DIR}/ovpn-mobile-client.ovpn" "$cfg"
    ;;
  router)
    cfg="$VPN_OUTPUT_DIR/$CLIENT_NAME/$CLIENT_NAME.conf"
    cp "${TEMPLATE_DIR}/ovpn-router-client.conf" "$cfg"
    ;;
esac

patch_ovpn_client_placeholders "$cfg" "$CLIENT_NAME" "$VPN_HOST" "$VPN_PORT" "$VPN_PORT_FALLBACK"

# -----------------------------
# Archive
# -----------------------------
if [[ "$ARCHIVE" == "true" ]]; then
  info "Compressing client directory..."
  7z a -t7z "$VPN_OUTPUT_DIR/$CLIENT_NAME.7z" "$VPN_OUTPUT_DIR/$CLIENT_NAME" >/dev/null
else
  info "Archive skipped (--no-archive)."
fi

info "Done."
info "Output: $VPN_OUTPUT_DIR/$CLIENT_NAME"
