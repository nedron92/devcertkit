# devcertkit - Version 0.1.0

Simple toolkit for generating internal SSL certificates and VPN infrastructure artifacts (OpenVPN) using your own private Certificate Authority (CA).

**Note:** This toolkit is designed to simplify both SSL and VPN certificate/config management. While SSL is fully functional, VPN features are currently in development and will be implemented soon.

Built for:
- homelabs
- selfhosted services
- internal HTTPS environments
- VPN-connected infrastructure (OpenVPN)
- development and testing environments

This project is based on a collection of private helper scripts originally created in 2023 and continuously improved over time for real-world usage.

---

# Why?

Managing internal SSL certificates and VPN configurations manually using OpenSSL or EasyRSA can quickly become frustrating and error-prone.

Especially for setups like:
- `git.home`
- `admin.home`
- `config.router`

or internal VPN-connected services where proper HTTPS should still exist and secure remote access is required.

This project aims to simplify:
- certificate generation (SSL & VPN)
- SAN handling & wildcard certificates
- PEM bundle creation
- OpenWRT/uhttpd compatibility
- OpenVPN client & server config management (Planned)
- internal infrastructure workflows

without fighting OpenSSL or EasyRSA commands directly.

---

# Features

### SSL (Current)
- EasyRSA-based certificate generation
- Support for multiple SAN domains & Wildcards
- OpenWRT/uhttpd output mode
- Optional PEM bundle & CA bundle creation
- Output packaging via 7z

### VPN (Planned / In Progress)
- OpenVPN CA and PKI management
- Simplified client certificate & config generation (.ovpn)
- Client / Server configuration helpers
- Workspace-based client management

### General
- Workspace-based structure (Runtime/output separation)
- Automatic workspace initialization
- Automatic CA creation or existing CA import
- EasyRSA backend resolution and setup handling

---

# Project Status

This project is currently in an early restructuring phase.

**Current State:**
- SSL management is **functional** and used in real-world private environments.
- VPN management is **planned** (porting existing scripts from 2023).
- Codebase is being cleaned up and generalized for public usage.

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
- EasyRSA backend (automatically resolved or provided manually)

The toolkit handles:
- Automatic workspace initialization
- Automatic CA creation or existing CA import
- Backend resolution and setup handling

---

# Current Workspace Structure

```text
devcertkit             # Main entry point

config/
  ca/
    ssl/               # CA for SSL certificates (ca.crt, ca.key)
    vpn/               # CA for VPN (planned)
  easyrsa/             # EasyRSA vars and configurations

runtime/
  .easyrsa/            # Symlink to EasyRSA backend
  ssl/pki/             # Internal EasyRSA PKI for SSL
  vpn/pki/             # Internal EasyRSA PKI for VPN (planned)

output/
  certs/               # Generated SSL certificates
  clients/             # Generated VPN clients (planned)

scripts/
  common/              # Shared helper scripts
  ssl/                 # SSL certificate creation toolkit
```

---

# Example Usage

Initialize the workspace and setup EasyRSA:

```bash
./devcertkit init
```

### SSL Management

Initialize SSL PKI and prepare the CA (imports existing or offers to create a new one):

```bash
./devcertkit ssl init
```

Generate a simple certificate:

```bash
./devcertkit ssl cert create -d git.home
```

Generate wildcard certificate:

```bash
./devcertkit ssl cert create --wildcard -d example.home
```

Generate OpenWRT/uhttpd compatible files:

```bash
./devcertkit ssl cert create \
  --openwrt \
  --include-ca \
  -d config.router
```

Create PEM bundle:

```bash
./devcertkit ssl cert create \
  --create-pem \
  --include-ca \
  -d mail.home
```

### VPN Management (Upcoming)

*Commands for VPN management are currently being ported.*

---

# Main Commands

- `init`: Setup the workspace and link EasyRSA.
- `ssl init`: Setup the SSL PKI and CA.
- `ssl cert create`: Generate and sign new SSL certificates.
- `ssl ca info`: Show information about the current SSL CA.
- `ssl cert info`: Show information about a generated certificate.

Run `./devcertkit help` or `./devcertkit ssl help` for more details.

---

# Planned Features

Planned improvements include:
- [x] proper bootstrap/init workflow
- [x] automatic EasyRSA download/setup (resolution and linking)
- [x] shared helper libraries
- [x] improved workspace handling
- [x] unified CLI
- [x] automatic CA creation
- [ ] OpenVPN client tooling (originally created in 2023, needs refactoring)
- [ ] better configuration management

---

# License

Work in progress.
Licensing will be clarified before the first stable public release.

EasyRSA itself is licensed separately by the OpenVPN community.