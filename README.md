# hkuvpn-nix

Connect to HKUVPN (2FA) from NixOS as a **local SOCKS5 proxy**, with no tun
device and no root.

Plain `openconnect` routes everything through the VPN, conflicts with mihomo,
and asks for your account and PIN every time. `hkuvpn` uses only a SOCKS5 port
and keeps the credentials in the keyring, so you type just the 2FA code.

For an HTTP proxy, background mode, or macOS / Windows, see
[rqhu1995/docker-vpn](https://github.com/rqhu1995/docker-vpn).
Unofficial; not affiliated with HKU ITS.

## How it works

`openconnect` connects to `vpn2fa.hku.hk` and hands the tunnel to
[`ocproxy`](https://github.com/cernekee/ocproxy), which exposes it as a SOCKS5
server on localhost. Routes and DNS stay untouched; only apps you point at the
proxy use the VPN. It is TCP only, and apps without SOCKS support need
`proxychains` or similar.

## Install

You need an unlocked Secret Service keyring (GNOME Keyring, KeePassXC,
KWallet, ...) and HKU 2FA already enrolled.

Try it first:

```sh
nix run github:Airzh1124/hkuvpn-nix -- set-password
nix run github:Airzh1124/hkuvpn-nix
```

Or add it to your flake inputs:

```nix
inputs.hkuvpn.url = "github:Airzh1124/hkuvpn-nix";
inputs.hkuvpn.inputs.nixpkgs.follows = "nixpkgs";
```

and in your NixOS configuration (Home Manager: `homeModules.default`):

```nix
{ inputs, ... }:
{
  imports = [ inputs.hkuvpn.nixosModules.default ];

  programs.hkuvpn = {
    enable = true;
    # socksPort = 1080;
    # server = "vpn2fa.hku.hk";
  };
}
```

The plain package is `packages.${system}.default`; `overlays.default` adds
`pkgs.hkuvpn`.

## Usage

```sh
hkuvpn set-password   # once; saves your account and Portal PIN in the keyring
hkuvpn                # connect, type the 2FA code; Ctrl-C disconnects
```

Your UID never ends up in your Nix config. `HKUVPN_SERVER` and `HKUVPN_PORT`
override the configured values for one run.

```sh
curl -x socks5h://127.0.0.1:1080 https://example.hku.hk/
```

```
# ~/.ssh/config
Host *.hku.hk
  ProxyCommand nc -X 5 -x 127.0.0.1:1080 %h %p
```

## With mihomo (Clash)

Route HKU domains to the proxy and leave everything else alone:

```yaml
proxies:
  - { name: HKU-SOCKS5, type: socks5, server: 127.0.0.1, port: 1080, udp: false }

proxy-groups:
  # Falls back to DIRECT when hkuvpn is not running.
  - name: HKU
    type: fallback
    proxies: [HKU-SOCKS5, DIRECT]
    url: https://www.gstatic.com/generate_204
    interval: 10
    lazy: true

rules:
  # Keep the VPN gateway itself out of the tunnel.
  - DOMAIN,vpn2fa.hku.hk,DIRECT
  - DOMAIN,vpn2fa-a.hku.hk,DIRECT
  - DOMAIN,vpn2fa-b.hku.hk,DIRECT
  - DOMAIN-SUFFIX,hku.hk,HKU
  - DOMAIN-SUFFIX,hku.edu.hk,HKU
```

Put these above any broader rule (`GEOIP`, `MATCH`), and add
`exclude-filter: '^HKU-SOCKS5$'` to any `include-all: true` group.

## License

MIT
