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

# SSL related paths
SSL_CONFIG_DIR="${CONFIG_DIR}/ca/ssl"
SSL_CA_CRT="${SSL_CONFIG_DIR}/ca.crt"
SSL_CA_KEY="${SSL_CONFIG_DIR}/ca.key"
SSL_PKI_DIR="${RUNTIME_DIR}/ssl/pki"
SSL_PKI_PRIVATE_DIR="${SSL_PKI_DIR}/private"
SSL_OUTPUT_DIR="${OUTPUT_DIR}/certs"
SSL_VARS_FILE="${EASYRSA_CONFIG_DIR}/vars.ssl"
SSL_VARS_FILE_DEFAULT="${EASYRSA_CONFIG_DIR}/vars.ssl.default"

# VPN related paths
VPN_CONFIG_DIR="${CONFIG_DIR}/ca/vpn"
VPN_CA_CRT="${VPN_CONFIG_DIR}/ca.crt"
VPN_CA_KEY="${VPN_CONFIG_DIR}/ca.key"
VPN_TA_KEY="${VPN_CONFIG_DIR}/ta.key"
VPN_PKI_DIR="${RUNTIME_DIR}/vpn/pki"
VPN_PKI_PRIVATE_DIR="${VPN_PKI_DIR}/private"
VPN_OUTPUT_DIR="${OUTPUT_DIR}/clients"
VPN_VARS_FILE="${EASYRSA_CONFIG_DIR}/vars.vpn"
VPN_VARS_FILE_DEFAULT="${EASYRSA_CONFIG_DIR}/vars.vpn.default"
