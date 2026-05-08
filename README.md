# devcertkit - Version 0.0.1

Simple toolkit for generating internal SSL certificates and related infrastructure artifacts using your own private Certificate Authority (CA).

Built for:
- homelabs
- selfhosted services
- internal HTTPS environments
- VPN-connected infrastructure
- development and testing environments

This project is based on a collection of private helper scripts originally created in 2023 and continuously improved over time for real-world usage.

---

# Why?

Managing internal SSL certificates manually using OpenSSL or EasyRSA can quickly become frustrating and error-prone.

Especially for setups like:
- `git.home`
- `admin.home`
- `config.router`
- `status.modem`

or internal VPN-connected services where proper HTTPS should still exist.

This project aims to simplify:
- certificate generation
- SAN handling
- wildcard certificates
- PEM bundle creation
- OpenWRT/uhttpd compatibility
- internal infrastructure workflows

without fighting OpenSSL directly.

---

# Features

Current features include:

- EasyRSA-based certificate generation
- Support for multiple SAN domains
- Wildcard certificate support
- OpenWRT/uhttpd output mode
- Optional PEM bundle creation
- Optional CA bundle export
- Output packaging via 7z
- Workspace-based structure
- Runtime/output separation

---

# Project Status

This project is currently in an early restructuring phase.

The current implementation:
- is functional
- is already used in real-world private environments
- is being cleaned up and generalized for public usage

Expect:
- breaking changes
- restructuring
- missing documentation
- rough edges

during the initial development phase.

---

# Requirements

Currently required:
- Bash
- OpenSSL
- 7z
- EasyRSA backend

At the moment, a private CA must already exist beforehand.

Future versions will include:
- automatic workspace initialization
- automatic CA creation
- backend bootstrap/setup handling

---

# Current Workspace Structure

```text
devcertkit             # Main entry point

config/
  ca/
    ssl/               # CA for SSL certificates
    vpn/               # CA for VPN
  easyrsa/             # EasyRSA vars and configurations

runtime/
  .easyrsa/            # Symlink to EasyRSA backend
  ssl/pki/             # Internal EasyRSA PKI for SSL
  vpn/pki/             # Internal EasyRSA PKI for VPN

output/
  certs/               # Generated SSL certificates
  clients/             # Generated VPN clients

scripts/
  common/              # Shared helper scripts
  ssl/                 # SSL certificate creation toolkit
```

---

# Example Usage

Initialize the workspace:

```bash
./devcertkit
```

Generate a simple certificate:

```bash
./scripts/ssl/create-cert.sh -d git.home
```

Generate wildcard certificate:

```bash
./scripts/ssl/create-cert.sh --wildcard -d example.home
```

Generate OpenWRT/uhttpd compatible files:

```bash
./scripts/ssl/create-cert.sh \
  --openwrt \
  --include-ca \
  -d config.router
```

Create PEM bundle:

```bash
./scripts/ssl/create-cert.sh \
  --create-pem \
  --include-ca \
  -d mail.home
```

---

# Planned Features

Planned improvements include:

- OpenVPN client tooling
  - also originally created back in 2023 (need to be generalized and refactored)
- proper bootstrap/init workflow
- automatic EasyRSA download/setup
- shared helper libraries
- improved workspace handling
- unified CLI
- better configuration management

---

# License

Work in progress.
Licensing will be clarified before the first stable public release.

EasyRSA itself is licensed separately by the OpenVPN community.