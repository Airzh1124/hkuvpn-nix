usage() {
  cat <<EOF
Usage: hkuvpn [connect]     connect and serve SOCKS5 on 127.0.0.1:\$HKUVPN_PORT
       hkuvpn set-password  store the HKU Portal PIN in the desktop keyring
       hkuvpn --help

Environment (overrides the built-in defaults):
  HKU_USER       HKU account, e.g. youruid@connect.hku.hk${HKUVPN_DEFAULT_USER:+ (default: $HKUVPN_DEFAULT_USER)}
  HKUVPN_SERVER  VPN gateway (default: $HKUVPN_DEFAULT_SERVER)
  HKUVPN_PORT    local SOCKS5 port (default: $HKUVPN_DEFAULT_PORT)
EOF
}

HKUVPN_USER="${HKU_USER:-$HKUVPN_DEFAULT_USER}"
HKUVPN_SERVER="${HKUVPN_SERVER:-$HKUVPN_DEFAULT_SERVER}"
HKUVPN_PORT="${HKUVPN_PORT:-$HKUVPN_DEFAULT_PORT}"

command="${1:-connect}"

case "$command" in
  -h | --help | help)
    usage
    exit 0
    ;;
  connect | set-password) ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [[ -z "$HKUVPN_USER" ]]; then
  echo "hkuvpn: no account set. Export HKU_USER=youruid@connect.hku.hk (or set programs.hkuvpn.user)." >&2
  exit 1
fi

if [[ "$command" == set-password ]]; then
  exec secret-tool store --label=HKUVPN service hkuvpn user "$HKUVPN_USER"
fi

# The port ends up inside the command line openconnect hands to a shell.
if [[ ! "$HKUVPN_PORT" =~ ^[0-9]+$ ]] || ((HKUVPN_PORT < 1 || HKUVPN_PORT > 65535)); then
  echo "hkuvpn: invalid HKUVPN_PORT: $HKUVPN_PORT" >&2
  exit 1
fi

# ocproxy only finds out after login that it cannot bind, which wastes a 2FA
# code and leaves openconnect running with no proxy. Check up front instead.
if (exec 3<>"/dev/tcp/127.0.0.1/$HKUVPN_PORT") 2>/dev/null; then
  echo "hkuvpn: 127.0.0.1:$HKUVPN_PORT is already in use (another hkuvpn session?). Stop it or set HKUVPN_PORT." >&2
  exit 1
fi

echo "hkuvpn: $HKUVPN_USER ->$HKUVPN_SERVER, SOCKS5 on 127.0.0.1:$HKUVPN_PORT (Ctrl-C to disconnect)" >&2

export HKUVPN_USER HKUVPN_SERVER HKUVPN_PORT
exec expect -f "$HKUVPN_EXPECT_SCRIPT"
