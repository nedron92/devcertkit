#!/usr/bin/env bash
#
# Part of the devcertkit toolkit.
# This script handles the creation of SSL certificates using a private CA.
# It uses EasyRSA as a backend and provides options for wildcards, SANs,
# OpenWrt/uhttpd compatibility, and PEM bundles.
#
# Examples:
#   git.home (your local / home git-server)
#   admin.home (your local / home admin-ui / dashboard)
#   config.router (your Router-UI, e.g. openwrt LuCI)
#

set -Eeuo pipefail

# -----------------------------
# Config (can be overridden via CLI flags)
# -----------------------------
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../common/shared.sh
source "${SCRIPT_DIR}/../common/shared.sh"
# shellcheck source=../common/paths.sh
source "${SCRIPT_DIR}/../common/paths.sh"

# Keep the SSL PKI location explicit for all SSL commands.
export EASYRSA_PKI="${SSL_PKI_DIR}"

WILDCARD="false"
ARCHIVE="true"   	# if false -> skip 7z
BATCH="false"    	# if true -> set EASYRSA_BATCH=1 (non-interactive)
OPENWRT="false"		# if true -> rename key/crt files directly to uhttpd.key / uhttpd.crt
INCLUDE_CA="false"	# if true -> include ca.crt directly in output-dir
CREATE_PEM="false"	# if true -> create a pem-file directly in output-dir

DOMAINS=()

# -----------------------------
# Helpers
# -----------------------------
show_help() {
  # Displays the help message for the cert-create.sh script.

  cat <<EOF
Usage: ./devcertkit ssl cert create [OPTIONS]

Options:
  -d, --domain <name>     Domain name for the certificate. Repeat for altNames.
      --wildcard          Also include wildcard for the *first* domain (e.g. *.example.com).
      --openwrt           Rename output files to OpenWrt/uhttpd defaults:
                          uhttpd.crt and uhttpd.key (instead of <domain>.crt/.key).
      --include-ca        Also copy ca.crt into the output directory (default: false).
      --create-pem        Create an additional PEM bundle (cert + key, CA not included by default).
      --batch             Run EasyRSA in batch mode (non-interactive) if supported.
      --no-archive        Do not create a 7z archive.
      --out-dir <path>    Output directory (default: ${SSL_OUTPUT_DIR})
      --ca-dir <path>     Existing CA directory (default: ${SSL_CONFIG_DIR})
  -h, --help              Show this help message.

Examples:
  # Simple cert (CN=example.com)
  ./devcertkit ssl cert create -d example.com

  # With additional SAN
  ./devcertkit ssl cert create -d example.com -d www.example.com

  # Wildcard for first domain (CN=*.example.com, SAN includes example.com + *.example.com)
  ./devcertkit ssl cert create --wildcard -d example.com

  # OpenWrt uhttpd filenames (uhttpd.crt/uhttpd.key)
  ./devcertkit ssl cert create --openwrt -d example.com

  # OpenWrt + include CA cert
  ./devcertkit ssl cert create --openwrt --include-ca -d example.com

  # Custom output directory, skip archive
  ./devcertkit ssl cert create --out-dir ../certs --no-archive -d example.com

  # Create cert, key and PEM bundle (PEM contains cert + key + CA)
  ./devcertkit ssl cert create -d example.com --create-pem --include-ca

  # Create cert + key + PEM bundle (without CA certificate)
  ./devcertkit ssl cert create -d example.com --create-pem
EOF
}

cleanup_on_error() {
  # Trap handler for script failures.
  # Prints the exit code to stderr if it's non-zero.

  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo "Script failed (exit code: $exit_code)." >&2
  fi
}
trap cleanup_on_error EXIT

join_san_dns() {
  # Formats a list of domains into a Subject Alternative Name (SAN) string
  # suitable for EasyRSA/OpenSSL (e.g., "DNS:example.com,DNS:www.example.com").
  # Arguments:
  #   $@: list of domain names
  # Returns:
  #   The formatted SAN string.

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
  # Renames generated certificate and key files to OpenWrt/uhttpd default names
  # (uhttpd.crt and uhttpd.key) within the specified directory.
  # Arguments:
  #   $1: base domain name used for the original files
  #   $2: directory containing the files

  local domain="$1"
  local cert_dir="$2"

  local src_crt="${cert_dir}/${domain}.crt"
  local src_key="${cert_dir}/${domain}.key"

  local dst_crt="${cert_dir}/uhttpd.crt"
  local dst_key="${cert_dir}/uhttpd.key"

  [[ -f "$src_crt" ]] || fail "Missing certificate to rename: $src_crt"
  [[ -f "$src_key" ]] || fail "Missing key to rename: $src_key"

  mv -f "$src_crt" "$dst_crt"
  mv -f "$src_key" "$dst_key"

  info "Renamed for OpenWrt/uhttpd:"
  info "  ${domain}.crt -> uhttpd.crt"
  info "  ${domain}.key -> uhttpd.key"
}

create_pem_bundle() {
  # Creates a combined PEM bundle containing the certificate and private key.
  # If configured, it also appends the CA certificate to the bundle.
  # Arguments:
  #   $1: base domain name (or "uhttpd" if OpenWrt mode is on)
  #   $2: directory containing the source files

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

  [[ -f "$crt_file" ]] || fail "Missing certificate for PEM bundle: $crt_file"
  [[ -f "$key_file" ]] || fail "Missing key for PEM bundle: $key_file"

  # Write cert + key into a single PEM file (order is commonly cert first, then key)
  cat "$crt_file" "$key_file" > "$pem_file"

  # Optionally include CA cert at the end (chain)
  if [[ "${INCLUDE_CA}" == "true" && -f "${cert_dir}/ca.crt" ]]; then
    cat "${cert_dir}/ca.crt" >> "$pem_file"
  fi

  info "PEM bundle created: $(basename "$pem_file")"
}

# -----------------------------
# Environment checks & setup
# -----------------------------
ensure_environment() {
  # Verifies that all necessary tools and directories are available before
  # proceeding with certificate creation. Fails if requirements are not met.

  [[ ${#DOMAINS[@]} -gt 0 ]] || fail "Please provide at least one domain using -d/--domain."

  # Ensure EasyRSA is resolved
  if [[ ! -x "${EASYRSA_BIN}" ]]; then
     fail "EasyRSA not found at ${EASYRSA_BIN}. Please run 'devcertkit init' at first."
  fi

  # Ensure SSL PKI is initialized
  if [[ ! -d "${SSL_PKI_DIR}" || ! -d "${SSL_PKI_PRIVATE_DIR}" || ! -d "${SSL_PKI_DIR}/issued" ]]; then
     fail "SSL PKI not initialized. Please run 'devcertkit ssl init' at first."
  fi

  # If archiving is enabled, ensure 7z exists
  if [[ "${ARCHIVE}" == "true" ]]; then
    need_cmd "7z"
  fi

  prepare_dir "${SSL_OUTPUT_DIR}"
}

# -----------------------------
# Main operation
# -----------------------------
create_ssl_cert() {
  # The main orchestration function for generating and signing an SSL certificate.
  # It handles CN/SAN determination, calls EasyRSA to generate and sign the
  # request, and manages the output files (copying, renaming, bundling, archiving).

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
  else
    export EASYRSA_BATCH=
  fi

  # Generate request (nopass -> no passphrase on private key)
  "${EASYRSA_BIN}" \
    --subject-alt-name="${san}" \
    --req-cn="${cn}" \
    gen-req "${cn}" nopass

  info "\nSigning request as server cert..."
  "${EASYRSA_BIN}" \
    --subject-alt-name="${san}" \
    sign-req server "${cn}"
  info "Finished signing."

  # Copy generated files
  local issued_crt="${SSL_PKI_DIR}/issued/${cn}.crt"
  local private_key="${SSL_PKI_DIR}/private/${cn}.key"

  check_file "${issued_crt}"
  check_file "${private_key}"

  local output_dir="${SSL_OUTPUT_DIR}/${safe_name}"
  cp -f "${issued_crt}" "${output_dir}/${safe_name}.crt"
  cp -f "${private_key}" "${output_dir}/${safe_name}.key"

  if [[ "${INCLUDE_CA}" == "true" ]]; then
	  cp -f "${SSL_PKI_DIR}/ca.crt" "${output_dir}/ca.crt"
  fi

  info "\nWrote:"
  info "  ${output_dir}/${safe_name}.crt"
  info "  ${output_dir}/${safe_name}.key"

  if [[ "${INCLUDE_CA}" == "true" ]]; then
	  info "  ${output_dir}/ca.crt"
  fi

  if [[ "${OPENWRT}" == "true" ]]; then
	  rename_to_openwrt_uhttpd_files "${safe_name}" "${output_dir}"
  fi

  if [[ "${CREATE_PEM}" == "true" ]]; then
	  create_pem_bundle "${safe_name}" "${output_dir}"
  fi

  if [[ "${ARCHIVE}" == "true" ]]; then
    info "\nCreating archive..."
    ( cd "$(dirname "${output_dir}")" && 7z a -t7z "${safe_name}.7z" "${safe_name}" >/dev/null )
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
      [[ -n "${2:-}" ]] || fail "Missing value for $1"
      val="$2"
      # Autodetect wildcard if first domain starts with *.
      if [[ ${#DOMAINS[@]} -eq 0 && "$val" == \*.* ]]; then
        WILDCARD="true"
        val="${val#*.}"
        info "Autodetected wildcard for base domain: ${val}"
      fi
      DOMAINS+=("$val")
      shift 2
      ;;
    --wildcard)
      WILDCARD="true"
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
      [[ -n "${2:-}" ]] || fail "Missing value for $1"
      SSL_OUTPUT_DIR="$2"
      shift 2
      ;;
    --ca-dir)
      [[ -n "${2:-}" ]] || fail "Missing value for $1"
      SSL_CONFIG_DIR="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      fail "Unknown option: $1 (use -h/--help)"
      ;;
  esac
done

ensure_environment
create_ssl_cert
