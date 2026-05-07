#!/usr/bin/env bash

# devcertkit -- SSL certificate helper toolkit
#
# Simple wrapper around EasyRSA for generating internal SSL certificates
# using your own private Certificate Authority (CA).
#
# Designed for:
#   - homelab environments
#   - internal HTTPS services
#   - OpenWRT/uhttpd certificates
#   - private development domains
#   - VPN-connected internal infrastructure
#
# Examples:
#   git.home (your local / home git-server)
#   admin.home (your local / home admin-ui / dashboard)
#   config.router (your Router-UI, e.g. openwrt LuCI)
#
# Requirements:
#   A private CA must be initialized beforehand.
#
# Backend:
#   EasyRSA 3.x
#
# Project:
#   https://github.com/nedron92/devcertkit

# TODO:
# - replace temporary .rnd workaround

set -Eeuo pipefail

# -----------------------------
# Config (can be overridden via CLI flags)
# -----------------------------
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./common/paths.sh
source "${SCRIPT_DIR}/common/paths.sh"
export EASYRSA_PKI="${SSL_PKI_DIR}"

# shellcheck source=./common/easyrsa-prepare.sh
source "${SCRIPT_DIR}/common/easyrsa-prepare.sh"

WILDCARD="false"
CLEAN_ONLY="false"
ARCHIVE="true"   	# if false -> skip 7z
BATCH="false"    	# if true -> set EASYRSA_BATCH=1 (non-interactive)
OPENWRT="false"		# if true -> rename key/crt files directly to uhttpd.key / uhttpd.crt
INCLUDE_CA="false"	# if true -> include ca.crt directly in output-dir
CREATE_PEM="false"	# if true -> create a pem-file directly in output-dir

DOMAINS=()

# -----------------------------
# Helpers
# -----------------------------
die() {
  echo "Error: $*" >&2
  exit 1
}

info() {
  echo -e "$*"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: '$1'"
}

check_file() {
  [[ -f "$1" ]] || die "Missing file: $1"
}

check_dir() {
  [[ -d "$1" ]] || die "Missing directory: $1"
}

cleanup_on_error() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo "Script failed (exit code: $exit_code)." >&2
  fi
}
trap cleanup_on_error EXIT

sanitize_name() {
  # Convert a domain or wildcard domain into a filesystem-safe identifier.
  #
  # Examples:
  #   "*.example.com"  -> "wildcard_example_com"
  #   "example.com"    -> "example_com"
  #   "foo-bar.test"   -> "foo-bar_test"

  local input="$1"
  local name

  # Handle wildcard prefix explicitly
  if [[ "$input" == \*.* ]]; then
    name="wildcard_${input#*.}"
  else
    name="$input"
  fi

  # Replace dots with underscores
  name="${name//./_}"

  # Replace any remaining invalid characters with underscore
  name="$(echo "$name" | sed 's/[^a-zA-Z0-9_-]/_/g')"

  echo "$name"
}


join_san_dns() {
  # Build a SAN string for EasyRSA: "DNS:example.com,DNS:www.example.com"
  local -a arr=("$@")
  local out=""
  local d
  for d in "${arr[@]}"; do
    [[ -n "$d" ]] || continue
    if [[ -z "$out" ]]; then
      out="DNS:${d}"
    else
      out="${out},DNS:${d}"
    fi
  done
  echo "$out"
}

rename_to_openwrt_uhttpd_files() {
  # Rename certificate + key files to OpenWrt/uhttpd defaults.
  # After this, only uhttpd.crt and uhttpd.key will exist (plus ca.crt).
  #
  # Expected:
  #   <domain>.crt
  #   <domain>.key
  #
  # Result:
  #   uhttpd.crt
  #   uhttpd.key

  local domain="$1"
  local cert_dir="$2"

  local src_crt="${cert_dir}/${domain}.crt"
  local src_key="${cert_dir}/${domain}.key"

  local dst_crt="${cert_dir}/uhttpd.crt"
  local dst_key="${cert_dir}/uhttpd.key"

  [[ -f "$src_crt" ]] || die "Missing certificate to rename: $src_crt"
  [[ -f "$src_key" ]] || die "Missing key to rename: $src_key"

  mv -f "$src_crt" "$dst_crt"
  mv -f "$src_key" "$dst_key"

  info "Renamed for OpenWrt/uhttpd:"
  info "  ${domain}.crt -> uhttpd.crt"
  info "  ${domain}.key -> uhttpd.key"
}

create_pem_bundle() {
  # Create a combined PEM bundle alongside the existing .crt and .key files.
  #
  # Input (expected):
  #   <cert_dir>/<domain>.crt  OR <cert_dir>/uhttpd.crt
  #   <cert_dir>/<domain>.key  OR <cert_dir>/uhttpd.key
  # Optional:
  #   <cert_dir>/ca.crt        (only included if INCLUDE_CA=true and file exists)
  #
  # Output:
  #   <cert_dir>/<domain>.pem  OR <cert_dir>/uhttpd.pem (depending on OPENWRT flag)

  local domain="$1"
  local cert_dir="$2"

  local crt_file key_file pem_file

  if [[ "${OPENWRT}" == "true" ]]; then
    crt_file="${cert_dir}/uhttpd.crt"
    key_file="${cert_dir}/uhttpd.key"
    pem_file="${cert_dir}/uhttpd.pem"
  else
    crt_file="${cert_dir}/${domain}.crt"
    key_file="${cert_dir}/${domain}.key"
    pem_file="${cert_dir}/${domain}.pem"
  fi

  [[ -f "$crt_file" ]] || die "Missing certificate for PEM bundle: $crt_file"
  [[ -f "$key_file" ]] || die "Missing key for PEM bundle: $key_file"

  # Write cert + key into a single PEM file (order is commonly cert first, then key)
  cat "$crt_file" "$key_file" > "$pem_file"

  # Optionally include CA cert at the end (chain)
  if [[ "${INCLUDE_CA}" == "true" && -f "${cert_dir}/ca.crt" ]]; then
    cat "${cert_dir}/ca.crt" >> "$pem_file"
  fi

  info "PEM bundle created: $(basename "$pem_file")"
}

show_help() {
  cat <<EOF
Usage: ./${SCRIPT_NAME} [OPTIONS]

Options:
  -d, --domain <name>     Domain name for the certificate. Repeat for altNames.
      --wildcard          Also include wildcard for the *first* domain (e.g. *.example.com).
      --openwrt           Rename output files to OpenWrt/uhttpd defaults:
                          uhttpd.crt and uhttpd.key (instead of <domain>.crt/.key).
      --include-ca        Also copy ca.crt into the output directory (default: false).
      --create-pem        Create an additional PEM bundle (cert + key, CA not included by default).
      --clean             Delete the PKI directory and exit.
      --batch             Run EasyRSA in batch mode (non-interactive) if supported.
      --no-archive        Do not create a 7z archive.
      --out-dir <path>    Output directory (default: ${SSL_OUTPUT_DIR})
      --ca-dir <path>     Existing CA directory (default: ${SSL_CONFIG_DIR})
  -h, --help              Show this help message.

Examples:
  # Simple cert (CN=example.com)
  ./${SCRIPT_NAME} -d example.com

  # With additional SAN
  ./${SCRIPT_NAME} -d example.com -d www.example.com

  # Wildcard for first domain (CN=*.example.com, SAN includes example.com + *.example.com)
  ./${SCRIPT_NAME} --wildcard -d example.com

  # OpenWrt uhttpd filenames (uhttpd.crt/uhttpd.key)
  ./${SCRIPT_NAME} --openwrt -d example.com

  # OpenWrt + include CA cert
  ./${SCRIPT_NAME} --openwrt --include-ca -d example.com

  # Custom output directory, skip archive
  ./${SCRIPT_NAME} --out-dir ../certs --no-archive -d example.com

  # Create cert, key and PEM bundle (PEM contains cert + key + CA)
  ./${SCRIPT_NAME} -d example.com --create-pem --include-ca

  # Create cert + key + PEM bundle (without CA certificate)
  ./${SCRIPT_NAME} -d example.com --create-pem
EOF
}


# -----------------------------
# Environment checks & setup
# -----------------------------
ensure_environment() {
  [[ ${#DOMAINS[@]} -gt 0 ]] || die "Please provide at least one domain using -d/--domain."

  check_file "${EASYRSA_BIN}"

  # If archiving is enabled, ensure 7z exists
  if [[ "${ARCHIVE}" == "true" ]]; then
    need_cmd "7z"
  fi

  # Existing CA prerequisites
  check_dir "${SSL_CONFIG_DIR}"
  check_file "${SSL_CONFIG_DIR}/ca.crt"
  check_file "${SSL_CONFIG_DIR}/ca.key"
  check_file "${VARS_FILE}"
}

init_pki_if_missing() {
  # Initialize PKI and Build CA if PKI is missing
  if [[ ! -d "${SSL_PKI_DIR}" || ! -d "${SSL_PKI_PRIVATE_DIR}" || ! -f "${SSL_PKI_DIR}/vars" ]]; then
    info "Initializing PKI..."
    "${EASYRSA_BIN}" init-pki
    openssl rand -writerand "${SSL_PKI_DIR}/.rnd"

    # EasyRSA expects a CA structure during initialization.
    # The generated CA is replaced immediately afterwards
    # with the configured existing CA files.
    prepare_ca "${SSL_CONFIG_DIR}" "${SSL_PKI_DIR}" "${SSL_PKI_PRIVATE_DIR}"
  fi
}

# -----------------------------
# Main operation
# -----------------------------
create_ssl_cert() {
  init_pki_if_missing

  local base_domain="${DOMAINS[0]}"

  # Determine CN and SANs
  local cn="${base_domain}"
  local -a san_domains=("${DOMAINS[@]}")

  if [[ "${WILDCARD}" == "true" ]]; then
    # Only apply wildcard to the first domain (common expectation)
    cn="*.${base_domain}"
    # Add wildcard to SANs, plus base domain is already present via DOMAINS[0]
    san_domains=("${san_domains[@]}" "*.${base_domain}")
  fi

  # Build SAN string for EasyRSA
  local san
  san="$(join_san_dns "${san_domains[@]}")"

  # Use a filesystem-safe request/cert name
  local safe_name
  safe_name="$(sanitize_name "${cn}")"

  # Export output target
  mkdir -p "${SSL_OUTPUT_DIR}/${safe_name}"

  info "\nGenerating request for base domain '${base_domain}' (wildcard: ${WILDCARD})..."
  info "  CN:  ${cn}"
  info "  SAN: ${san}\n"

  # Batch mode for easyrsa signing prompts (optional)
  if [[ "${BATCH}" == "true" ]]; then
    export EASYRSA_BATCH=1
  fi

  # Generate request (nopass -> no passphrase on private key)
  "${EASYRSA_BIN}" \
    --subject-alt-name="${san}" \
    --req-cn="${cn}" \
    gen-req "${cn}" nopass

  info "\nSigning request as server cert..."
  "${EASYRSA_BIN}" sign-req server "${cn}"
  info "Finished signing."

  # Copy generated files
  local issued_crt="${SSL_PKI_DIR}/issued/${cn}.crt"
  local private_key="${SSL_PKI_DIR}/private/${cn}.key"

  check_file "${issued_crt}"
  check_file "${private_key}"

  cp -f "${issued_crt}" "${SSL_OUTPUT_DIR}/${safe_name}/${safe_name}.crt"
  cp -f "${private_key}" "${SSL_OUTPUT_DIR}/${safe_name}/${safe_name}.key"
  
  if [[ "${INCLUDE_CA}" == "true" ]]; then
	cp -f "${SSL_PKI_DIR}/ca.crt" "${SSL_OUTPUT_DIR}/${safe_name}/ca.crt"
  fi

  info "\nWrote:"
  info "  ${SSL_OUTPUT_DIR}/${safe_name}/${safe_name}.crt"
  info "  ${SSL_OUTPUT_DIR}/${safe_name}/${safe_name}.key"
  
  if [[ "${INCLUDE_CA}" == "true" ]]; then
	info "  ${SSL_OUTPUT_DIR}/${safe_name}/ca.crt"
  fi
  
  if [[ "${OPENWRT}" == "true" ]]; then
	rename_to_openwrt_uhttpd_files "${safe_name}" "${SSL_OUTPUT_DIR}/${safe_name}"
  fi
  
  if [[ "${CREATE_PEM}" == "true" ]]; then
	create_pem_bundle "${safe_name}" "${SSL_OUTPUT_DIR}/${safe_name}"
  fi

  if [[ "${ARCHIVE}" == "true" ]]; then
    info "\nCreating archive..."
    ( cd "$(dirname "${SSL_OUTPUT_DIR}")" && 7z a -t7z "${safe_name}.7z" "${safe_name}" >/dev/null )
    info "Done. Archive: ${SSL_OUTPUT_DIR}/${safe_name}.7z"
  else
    info "\nDone. (Archive skipped)"
  fi
}

# -----------------------------
# Argument parsing
# -----------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--domain)
      [[ -n "${2:-}" ]] || die "Missing value for $1"
      DOMAINS+=("$2")
      shift 2
      ;;
    --wildcard)
      WILDCARD="true"
      shift
      ;;
    --clean)
      CLEAN_ONLY="true"
      shift
      ;;
    --batch)
      BATCH="true"
      shift
      ;;
    --no-archive)
      ARCHIVE="false"
      shift
      ;;
    --openwrt)
      OPENWRT="true"
      shift
      ;;
    --include-ca)
      INCLUDE_CA="true"
      shift
      ;;
    --create-pem)
      CREATE_PEM="true"
      shift
      ;;
    --out-dir)
      [[ -n "${2:-}" ]] || die "Missing value for $1"
      SSL_OUTPUT_DIR="$2"
      shift 2
      ;;
    --ca-dir)
      [[ -n "${2:-}" ]] || die "Missing value for $1"
      SSL_CONFIG_DIR="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      die "Unknown option: $1 (use -h/--help)"
      ;;
  esac
done

if [[ "${CLEAN_ONLY}" == "true" ]]; then
  rm -rf "${SSL_PKI_DIR}"
  echo "Deleted PKI dir: ${SSL_PKI_DIR}"
  exit 0
fi

ensure_environment
create_ssl_cert
