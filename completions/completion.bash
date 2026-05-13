# bash completion for devcertkit
# Source this file from bash, or install it into a bash-completion directory.
#
# Current supported command tree (v1.0.0):
#   devcertkit
#   devcertkit init
#   devcertkit ssl {init, ca {create,import,info}, cert {create,info}, clean}
#   devcertkit vpn {init, ca {create,import,info,gen-tls}, client {create,info}, clean}
#
# This completion is intentionally conservative and focuses on the current
# public CLI surface. It avoids guessing domain/client names.

_devcertkit_complete_root() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Global/root level
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "init ssl vpn version help -h --help -v --version --easyrsa-path" -- "${cur}") )
        return 0
    fi

    case "${COMP_WORDS[1]}" in
        init)
            if [[ "${prev}" == "--easyrsa-path" ]]; then
                compopt -o filenames 2>/dev/null || true
                COMPREPLY=( $(compgen -d -- "${cur}") )
                return 0
            fi
            COMPREPLY=( $(compgen -W "-h --help --easyrsa-path" -- "${cur}") )
            return 0
            ;;
        ssl)
            _devcertkit_complete_ssl
            return 0
            ;;
        vpn)
            _devcertkit_complete_vpn
            return 0
            ;;
        version|-v|--version|help|-h|--help)
            COMPREPLY=()
            return 0
            ;;
    esac

    COMPREPLY=()
    return 0
}

_devcertkit_complete_ssl() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # ssl <subcmd>
    if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "init ca cert clean help -h --help" -- "${cur}") )
        return 0
    fi

    case "${COMP_WORDS[2]}" in
        init)
            COMPREPLY=( $(compgen -W "-h --help" -- "${cur}") )
            return 0
            ;;
        clean)
            COMPREPLY=( $(compgen -W "-h --help" -- "${cur}") )
            return 0
            ;;
        ca)
            _devcertkit_complete_ssl_ca
            return 0
            ;;
        cert)
            _devcertkit_complete_ssl_cert
            return 0
            ;;
        help|-h|--help)
            COMPREPLY=()
            return 0
            ;;
    esac

    COMPREPLY=()
    return 0
}

_devcertkit_complete_ssl_ca() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # ssl ca <subcmd>
    if [[ ${COMP_CWORD} -eq 3 ]]; then
        COMPREPLY=( $(compgen -W "create import info help -h --help" -- "${cur}") )
        return 0
    fi

    case "${COMP_WORDS[3]}" in
        create)
            COMPREPLY=( $(compgen -W "-h --help" -- "${cur}") )
            return 0
            ;;
        import)
            COMPREPLY=( $(compgen -W "-h --help" -- "${cur}") )
            return 0
            ;;
        info)
            if [[ "${prev}" == "--file" ]]; then
                compopt -o filenames 2>/dev/null || true
                COMPREPLY=( $(compgen -f -- "${cur}") )
                return 0
            fi
            COMPREPLY=( $(compgen -W "-h --help --short --file" -- "${cur}") )
            return 0
            ;;
        help|-h|--help)
            COMPREPLY=()
            return 0
            ;;
    esac

    COMPREPLY=()
    return 0
}

_devcertkit_complete_ssl_cert() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # ssl cert <subcmd>
    if [[ ${COMP_CWORD} -eq 3 ]]; then
        COMPREPLY=( $(compgen -W "create info help -h --help" -- "${cur}") )
        return 0
    fi

    case "${COMP_WORDS[3]}" in
        create)
            _devcertkit_complete_ssl_cert_create
            return 0
            ;;
        info)
            if [[ "${prev}" == "--file" ]]; then
                compopt -o filenames 2>/dev/null || true
                COMPREPLY=( $(compgen -f -- "${cur}") )
                return 0
            fi
            COMPREPLY=( $(compgen -W "-h --help --short --file" -- "${cur}") )
            return 0
            ;;
        help|-h|--help)
            COMPREPLY=()
            return 0
            ;;
    esac

    COMPREPLY=()
    return 0
}

_devcertkit_complete_ssl_cert_create() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "${prev}" in
        -d|--domain)
            # Domain values are user-defined; do not speculate.
            COMPREPLY=()
            return 0
            ;;
        --out-dir|--ca-dir)
            compopt -o filenames 2>/dev/null || true
            COMPREPLY=( $(compgen -d -- "${cur}") )
            return 0
            ;;
    esac

    COMPREPLY=( $(compgen -W \
        "-d --domain --wildcard --openwrt --include-ca --create-pem --batch --archive --out-dir --ca-dir -h --help" \
        -- "${cur}") )
    return 0
}

_devcertkit_complete_vpn() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # vpn <subcmd>
    if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "init ca client clean help -h --help" -- "${cur}") )
        return 0
    fi

    case "${COMP_WORDS[2]}" in
        init)
            COMPREPLY=( $(compgen -W "-h --help" -- "${cur}") )
            return 0
            ;;
        clean)
            COMPREPLY=( $(compgen -W "-h --help" -- "${cur}") )
            return 0
            ;;
        ca)
            _devcertkit_complete_vpn_ca
            return 0
            ;;
        client)
            _devcertkit_complete_vpn_client
            return 0
            ;;
        help|-h|--help)
            COMPREPLY=()
            return 0
            ;;
    esac

    COMPREPLY=()
    return 0
}

_devcertkit_complete_vpn_ca() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # vpn ca <subcmd>
    if [[ ${COMP_CWORD} -eq 3 ]]; then
        COMPREPLY=( $(compgen -W "create import info gen-tls help -h --help" -- "${cur}") )
        return 0
    fi

    case "${COMP_WORDS[3]}" in
        create)
            COMPREPLY=( $(compgen -W "--pass -h --help" -- "${cur}") )
            return 0
            ;;
        import)
            COMPREPLY=( $(compgen -W "-h --help" -- "${cur}") )
            return 0
            ;;
        info)
            if [[ "${prev}" == "--file" ]]; then
                compopt -o filenames 2>/dev/null || true
                COMPREPLY=( $(compgen -f -- "${cur}") )
                return 0
            fi
            COMPREPLY=( $(compgen -W "-h --help --short --file" -- "${cur}") )
            return 0
            ;;
        gen-tls)
            COMPREPLY=( $(compgen -W "-h --help" -- "${cur}") )
            return 0
            ;;
        help|-h|--help)
            COMPREPLY=()
            return 0
            ;;
    esac

    COMPREPLY=()
    return 0
}

_devcertkit_complete_vpn_client() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # vpn client <subcmd>
    if [[ ${COMP_CWORD} -eq 3 ]]; then
        COMPREPLY=( $(compgen -W "create info help -h --help" -- "${cur}") )
        return 0
    fi

    case "${COMP_WORDS[3]}" in
        create)
            _devcertkit_complete_vpn_client_create
            return 0
            ;;
        info)
            if [[ "${prev}" == "--file" ]]; then
                compopt -o filenames 2>/dev/null || true
                COMPREPLY=( $(compgen -f -- "${cur}") )
                return 0
            fi
            COMPREPLY=( $(compgen -W "-h --help --short --file" -- "${cur}") )
            return 0
            ;;
        help|-h|--help)
            COMPREPLY=()
            return 0
            ;;
    esac

    COMPREPLY=()
    return 0
}

_devcertkit_complete_vpn_client_create() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "${prev}" in
        -t|--type)
            COMPREPLY=( $(compgen -W "general mobile router" -- "${cur}") )
            return 0
            ;;
        --vpn-port)
            COMPREPLY=()
            return 0
            ;;
    esac

    COMPREPLY=( $(compgen -W \
        "-t --type --no-pass --archive --vpn-port -h --help" \
        -- "${cur}") )
    return 0
}

complete -F _devcertkit_complete_root devcertkit
