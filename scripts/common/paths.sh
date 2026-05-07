#!/usr/bin/env bash

# Centralized path definitions for devcertkit

# Base directories
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${COMMON_DIR}/../.." && pwd)"

CONFIG_DIR="${ROOT_DIR}/config"
OUTPUT_DIR="${ROOT_DIR}/output"
RUNTIME_DIR="${ROOT_DIR}/runtime"

# EasyRSA paths
EASYRSA_DIR="${RUNTIME_DIR}/.easyrsa"
EASYRSA_BIN="${EASYRSA_DIR}/easyrsa"
EASYRSA_CONFIG_DIR="${CONFIG_DIR}/easyrsa"
VARS_FILE="${EASYRSA_CONFIG_DIR}/vars"

# SSL PKI paths
SSL_CONFIG_DIR="${CONFIG_DIR}/ca/ssl"
SSL_PKI_DIR="${RUNTIME_DIR}/ssl/pki"
SSL_PKI_PRIVATE_DIR="${SSL_PKI_DIR}/private"
SSL_OUTPUT_DIR="${OUTPUT_DIR}/certs"

# VPN PKI paths
VPN_CONFIG_DIR="${CONFIG_DIR}/ca/vpn"
VPN_PKI_DIR="${RUNTIME_DIR}/vpn/pki"
VPN_PKI_PRIVATE_DIR="${VPN_PKI_DIR}/private"
VPN_OUTPUT_DIR="${OUTPUT_DIR}/clients"

# Aliases for backward compatibility in scripts
PKI_DIR="${SSL_PKI_DIR}"
PKI_PRIVATE_DIR="${SSL_PKI_DIR}/private"

OUT_DIR="${SSL_OUTPUT_DIR}"
EXISTING_CA_DIR="${SSL_CONFIG_DIR}"
