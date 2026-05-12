# devcertkit

`devcertkit` is a simple toolkit wrapper for [EasyRSA](https://github.com/OpenVPN/easy-rsa).  
It streamlines the management of internal SSL certificates and VPN infrastructure (OpenVPN) using your own private Certificate Authority (CA).

Built for:
- Homelabs and self-hosted services
- Internal HTTPS environments
- Secure remote access (OpenVPN)
- Development and testing workflows

This project is based on a collection of private helper scripts and has been refined for ease of use and real-world reliability.

---

## Why devcertkit?

Managing internal SSL and VPN configurations directly via OpenSSL or EasyRSA can be complex and error-prone.  
`devcertkit` abstracts this complexity, making it easier to handle:  

- **Unified PKI Management:** Separate or shared PKIs for SSL and VPN.
- **Advanced SSL Support:** Multi-domain SAN, Wildcards, and PEM bundle creation.
- **VPN Ready:** Fully functional OpenVPN CA management and client configuration generation (`.ovpn`).
- **Device Compatibility:** Specific output modes for OpenWRT (uhttpd), mobile devices, and routers.
- **Automated Workflows:** Workspace-based structure with automatic CA creation or existing CA import.

---

## Features

### SSL Management
- EasyRSA-based certificate generation.
- Support for Subject Alternative Names (SAN) and Wildcards.
- OpenWRT/uhttpd compatibility mode.
- Optional PEM and CA bundle creation.
- Automated packaging of certificates via 7z.

### VPN Management
- Full OpenVPN CA and PKI management.
- Automated client certificate and `.ovpn` config generation.
- Multiple client templates: `general`, `mobile`, `router`.
- Automatic inclusion of necessary keys (ca.crt, ta.key) in client packages.

### General
- Workspace-based structure for clean separation of runtime and output.
- Automatic EasyRSA backend resolution and setup.
- Flexible configuration via settings files.

---

## Installation & Requirements

### Prerequisites
Ensure the following tools are installed:
- Bash
- OpenSSL
- 7z (for packaging)

### Setup
1. Clone the repository.
2. Initialize the workspace:
   ```bash
   ./devcertkit init
   ```
   This command prepares the environment and resolves the EasyRSA backend.

---

## Usage

### SSL Management

**Initialize SSL PKI:**
```bash
./devcertkit ssl init
```

**CA Management:**
- `ssl ca create`: Interactively create a new SSL CA.
- `ssl ca info`: Display details about the current SSL CA.
- `ssl ca import`: Import an existing CA from `config/ca/ssl`.

**Certificate Generation:**
- **Standard:** `./devcertkit ssl cert create -d git.home`
- **Wildcard:** `./devcertkit ssl cert create -d *.example.home`
- **OpenWRT:** `./devcertkit ssl cert create --openwrt -d config.router`
- **PEM Bundle:** `./devcertkit ssl cert create --create-pem -d mail.home`

**Information:**
```bash
./devcertkit ssl cert info git.home
```

### VPN Management

**Initialize VPN PKI:**
```bash
./devcertkit vpn init
```

**CA Management:**
- `vpn ca create`: Create a new VPN CA.
- `vpn ca info`: Display details about the VPN CA.
- `vpn ca import`: Import an existing CA from `config/ca/vpn`.

**Client Creation:**
Generate a client configuration and certificates:
```bash
# General client
./devcertkit vpn client create my-client

# Router-specific client (no password)
./devcertkit vpn client create -t router --no-pass my-router
```

**Options for client creation:**
- `-t, --type <type>`: `general`, `mobile`, or `router`.
- `--no-pass`: Skip password protection for the client key.
- `--no-archive`: Skip 7z compression.

---

## Project Structure

- `devcertkit`: Main entry point.
- `config/`: Configuration files and templates.
- `runtime/`: Internal PKI and EasyRSA backend.
- `output/`: Generated certificates and client packages.
- `scripts/`: Implementation details for SSL and VPN commands.

---

# Planned Features

Planned improvements include:
- [ ] automatic EasyRSA download, if not available
- [ ] OpenVPN server-config creation

---
## Credits
This project uses [EasyRSA](https://github.com/OpenVPN/easy-rsa)
for certificate and PKI management.

---

## License
MIT License
Copyright (c) 2026 nedron92

[EasyRSA](https://github.com/OpenVPN/easy-rsa?tab=License-1-ov-file) is licensed separately by the OpenVPN community.
