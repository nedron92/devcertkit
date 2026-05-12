#!/usr/bin/env bash
#
# Part of the devcertkit toolkit.
# This script displays information about an existing SSL / CA / VPN CA certificate.
# It can read certificates by domain- or client name (searching in output/*)
# or by absolute file path.
#

set -Eeuo pipefail

# -----------------------------
# Config
# -----------------------------
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./shared.sh
source "${SCRIPT_DIR}/shared.sh"
# shellcheck source=./paths.sh
source "${SCRIPT_DIR}/paths.sh"

SHORT_MODE="false"
FILE_PATH=""
DOMAIN=""

# -----------------------------
# Helpers
# -----------------------------
show_help() {
  cat <<EOF
Usage: ./devcertkit <ssl|vpn> cert info <domain|client> [OPTIONS]
       ./devcertkit <ssl|vpn> cert info --file <path> [OPTIONS]

Display information about an existing certificate.

Arguments:
  <domain|client>       Domain name (SSL) or Client name (VPN).
                        The script will search in appropriate output directory.

Options:
  --file <path>         Absolute path to the certificate file.
  --short               Only display expiration date and remaining validity.
  -h, --help            Show this help message.
EOF
}

get_cert_path_by_name() {
  local name="$1"
  local safe_name
  safe_name="$(sanitize_name "$name")"

  local cert_path=""

  # Try SSL output directory
  if [[ -d "${SSL_OUTPUT_DIR:-}" ]]; then
    cert_path="${SSL_OUTPUT_DIR}/${safe_name}/${safe_name}.crt"
    # Fallback: maybe it was renamed to uhttpd.crt
    if [[ ! -f "$cert_path" ]]; then
      cert_path="${SSL_OUTPUT_DIR}/${safe_name}/uhttpd.crt"
    fi

    # Fallback: try wildcard path for given domain
    if [[ ! -f "$cert_path" ]]; then
      local wildcard_name
      wildcard_name="$(sanitize_name "*.${name}")"

      local wildcard_cert_path="${SSL_OUTPUT_DIR}/${wildcard_name}/${wildcard_name}.crt"
      if [[ ! -f "$wildcard_cert_path" ]]; then
        wildcard_cert_path="${SSL_OUTPUT_DIR}/${wildcard_name}/uhttpd.crt"
      fi

      if [[ -f "$wildcard_cert_path" ]]; then
        cert_path="$wildcard_cert_path"
      fi
    fi
  fi

  # Try VPN output directory if not found in SSL
  if [[ ! -f "$cert_path" && -d "${VPN_OUTPUT_DIR:-}" ]]; then
     # For VPN clients, the path is often output/clients/<client>/<client>.crt
     local vpn_cert_path="${VPN_OUTPUT_DIR}/${safe_name}/${safe_name}.crt"
     if [[ -f "$vpn_cert_path" ]]; then
       cert_path="$vpn_cert_path"
     fi
  fi

  if [[ -f "$cert_path" ]]; then
    echo "$cert_path"
  else
    fail "No certificate found for '${name}' in SSL or VPN output directories."
  fi
}

# -----------------------------
# CLI Parsing
# -----------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    --file)
      if [[ -n "${2:-}" && "$2" != -* ]]; then
        FILE_PATH="$2"
        shift 2
      else
        fail "--file requires a path argument."
      fi
      ;;
    --short)
      SHORT_MODE="true"
      shift
      ;;
    -*)
      fail "Unknown option: $1"
      ;;
    *)
      if [[ -z "$DOMAIN" ]]; then
        DOMAIN="$1"
        shift
      else
        fail "Unexpected argument: $1 (domain already specified as $DOMAIN)"
      fi
      ;;
  esac
done

# Validation
if [[ -n "$DOMAIN" && -n "$FILE_PATH" ]]; then
  fail "Cannot specify both <domain> and --file."
fi

if [[ -z "$DOMAIN" && -z "$FILE_PATH" ]]; then
  show_help
  exit 1
fi

# Determine target file
TARGET_CERT=""
if [[ -n "$FILE_PATH" ]]; then
  TARGET_CERT="$FILE_PATH"
else
  TARGET_CERT="$(get_cert_path_by_name "$DOMAIN")"
fi

check_file "$TARGET_CERT"
need_cmd "openssl"

# -----------------------------
# Data Extraction
# -----------------------------
# CN
CN=$(openssl x509 -in "$TARGET_CERT" -noout -subject -nameopt RFC2253 | sed 's/.*CN=\([^,]*\).*/\1/')

# Issuer
ISSUER=$(openssl x509 -in "$TARGET_CERT" -noout -issuer -nameopt RFC2253 | sed 's/.*CN=\([^,]*\).*/\1/')

# SANs
SANS=$(openssl x509 -in "$TARGET_CERT" -noout -ext subjectAltName 2>/dev/null | grep -v "subjectAltName" | sed 's/^[[:space:]]*//' | tr -d '\n' || true)
if [[ -z "$SANS" ]]; then
    # Try alternative way to get SANs if grep didn't work as expected
    SANS=$(openssl x509 -in "$TARGET_CERT" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -n1 | sed 's/^[[:space:]]*//' | tr -d '\n' || true)
fi

# Dates
NOT_BEFORE=$(openssl x509 -in "$TARGET_CERT" -noout -startdate | cut -d= -f2)
NOT_AFTER=$(openssl x509 -in "$TARGET_CERT" -noout -enddate | cut -d= -f2)

# Time to expiration (seconds)
NOW_SEC=$(date +%s)
EXP_SEC=$(date -d "$NOT_AFTER" +%s)
REMAINING_SEC=$((EXP_SEC - NOW_SEC))
REMAINING_DAYS=$((REMAINING_SEC / 86400))

# Fingerprint (SHA256)
FINGERPRINT=$(openssl x509 -in "$TARGET_CERT" -noout -fingerprint -sha256 | cut -d= -f2)

# Key Info
KEY_ALG=$(openssl x509 -in "$TARGET_CERT" -noout -text | grep "Public Key Algorithm" | cut -d: -f2 | sed 's/^[[:space:]]*//' || echo "unknown")
KEY_BITS=$(openssl x509 -in "$TARGET_CERT" -noout -text | grep -E "Public-Key:|RSA Public-Key:" | sed 's/[^0-9]//g' || echo "unknown")

# -----------------------------
# Output
# -----------------------------
if [[ "$SHORT_MODE" == "true" ]]; then
    if [[ $REMAINING_SEC -lt 0 ]]; then
        info "Expired on: $NOT_AFTER (EXPIRED $(( -REMAINING_DAYS )) days ago)"
    else
        info "Expires on: $NOT_AFTER ($REMAINING_DAYS days remaining)"
    fi
else
    DISPLAY_NAME="${DOMAIN:-$FILE_PATH}"
    [[ -z "$DISPLAY_NAME" ]] && DISPLAY_NAME="$TARGET_CERT"

    info "Certificate Information for: ${DISPLAY_NAME}"
    info "--------------------------------------------------------"
    info "Subject CN:      $CN"
    info "Issuer:          $ISSUER"
    info "SANs:            ${SANS:-None}"
    info "Not Before:      $NOT_BEFORE"
    info "Not After:       $NOT_AFTER"
    if [[ $REMAINING_SEC -lt 0 ]]; then
        info "Status:          \033[0;31mEXPIRED\033[0m ($(( -REMAINING_DAYS )) days ago)"
    else
        info "Expires in:      $REMAINING_DAYS days"
    fi
    info "Key Algorithm:   $KEY_ALG (${KEY_BITS:-unknown} bits)"
    info "Fingerprint:     $FINGERPRINT"
    info "--------------------------------------------------------"
fi
