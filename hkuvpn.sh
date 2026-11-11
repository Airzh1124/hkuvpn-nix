usage() {
  cat <<EOF
Usage: hkuvpn [connect]     connect and serve SOCKS5 on 127.0.0.1:\$HKUVPN_PORT
       hkuvpn set-password  save your account and Portal PIN in the desktop keyring
       hkuvpn --help

Environment (overrides the built-in defaults):
  HKUVPN_SERVER  VPN gateway (default: $HKUVPN_DEFAULT_SERVER)
  HKUVPN_PORT    local SOCKS5 port (default: $HKUVPN_DEFAULT_PORT)
EOF
}

# Accounts that have a PIN in the keyring. secret-tool prints attributes on
# stderr and the secret on stdout, so dropping stdout means the PIN is never
# read here.
keyring_users() {
  { secret-tool search --all service hkuvpn 2>&1 >/dev/null || true; } |
    sed -n 's/^attribute\.user = //p'
}

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

# The keyring is the only place the account is kept.
mapfile -t saved < <(keyring_users)

if [[ "$command" == set-password ]]; then
  prompt="HKU account (youruid@connect.hku.hk)"
  current=""
  if ((${#saved[@]} == 1)); then
    current="${saved[0]}"
    prompt+=" [$current]"
  fi
  read -r -p "$prompt: " account
  account="${account:-$current}"
  if [[ -z "$account" ]]; then
    echo "hkuvpn: no account given." >&2
    exit 1
  fi

  secret-tool store --label=HKUVPN service hkuvpn user "$account"

  # Keep exactly one account, so connecting never has to guess.
  for old in "${saved[@]}"; do
    if [[ "$old" != "$account" ]]; then
      secret-tool clear service hkuvpn user "$old"
    fi
  done
  echo "hkuvpn: saved $account" >&2
  exit 0
fi

if ((${#saved[@]} == 0)); then
  echo "hkuvpn: no account saved yet. Run: hkuvpn set-password" >&2
  exit 1
elif ((${#saved[@]} > 1)); then
  {
    echo "hkuvpn: several accounts are saved in the keyring:"
    printf '  %s\n' "${saved[@]}"
    echo "Run 'hkuvpn set-password' to keep just one."
  } >&2
  exit 1
fi
HKUVPN_USER="${saved[0]}"

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

echo "hkuvpn: $HKUVPN_USER -> $HKUVPN_SERVER, SOCKS5 on 127.0.0.1:$HKUVPN_PORT (Ctrl-C to disconnect)" >&2

export HKUVPN_USER HKUVPN_SERVER HKUVPN_PORT
exec expect -f "$HKUVPN_EXPECT_SCRIPT"
