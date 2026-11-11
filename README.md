# hkuvpn-nix

Connect to HKUVPN (2FA) from NixOS as a **local SOCKS5 proxy**, with no tun
device and no root.

```console
$ hkuvpn
hkuvpn: youruid@connect.hku.hk -> vpn2fa.hku.hk, SOCKS5 on 127.0.0.1:1080 (Ctrl-C to disconnect)
...
Response: <type your 2FA code>
```

Then point whatever needs the campus network at `socks5h://127.0.0.1:1080`.

This is deliberately small: one command, four nixpkgs dependencies, no
daemon, no container. It fits you if you are on NixOS (or use Nix with Home
Manager on Linux), have a desktop keyring, and a SOCKS5 port is all you need.

If you want an HTTP proxy, background mode, macOS or Windows support, or
ready-made Clash / Surge rules, use
[rqhu1995/docker-vpn](https://github.com/rqhu1995/docker-vpn) instead; it
solves the same problem with Docker and covers much more ground.

Unofficial; not affiliated with or supported by HKU ITS.

## How it works

`openconnect` speaks the AnyConnect protocol to `vpn2fa.hku.hk`, but instead of
creating a tun device it hands the tunnel to
[`ocproxy`](https://github.com/cernekee/ocproxy), a userspace TCP/IP stack that
exposes it as a SOCKS5 server on localhost. The password comes from the desktop
keyring (`secret-tool`); the 2FA code is typed interactively.

### Why not the NetworkManager / tun setup?

| | tun device (NetworkManager, plain `openconnect`) | this (ocproxy) |
|---|---|---|
| Privileges | root, or a NetworkManager plugin | none |
| What goes through the VPN | whatever the pushed routes say | only apps you point at the proxy |
| System routes / DNS | changed while connected | untouched |
| Coexisting with another VPN or a TUN-mode proxy | route conflicts are common | independent |
| Non-TCP traffic (ICMP, UDP) | works | not supported |
| Apps without SOCKS support | work | need `proxychains` or similar |

Pick this if you only need a few things on campus (library e-resources, SSH to
a lab machine, an internal site) and want everything else to keep its normal
route. Pick the tun setup if you need the whole machine on the campus network.

## Try it without installing

```sh
nix run github:Airzh1124/hkuvpn-nix -- set-password   # once; asks for your account and PIN
nix run github:Airzh1124/hkuvpn-nix
```

## Install

Add the flake input:

```nix
inputs.hkuvpn.url = "github:Airzh1124/hkuvpn-nix";
inputs.hkuvpn.inputs.nixpkgs.follows = "nixpkgs";
```

NixOS:

```nix
{
  imports = [ inputs.hkuvpn.nixosModules.default ];

  programs.hkuvpn = {
    enable = true;
    # socksPort = 1080;
    # server = "vpn2fa.hku.hk";
  };
}
```

Home Manager: same options, with `inputs.hkuvpn.homeModules.default`.

Without the module, `inputs.hkuvpn.packages.${system}.default` is the plain
package, and `overlays.default` adds it as `pkgs.hkuvpn`.

## Setting your account

There is nothing to configure. `hkuvpn set-password` asks for your account
(`youruid@connect.hku.hk`) and Portal PIN and saves both in the desktop
keyring; `hkuvpn` reads them back from there. Neither ends up in your Nix
config or shell files, so a public config repository does not leak your UID.

Run `hkuvpn set-password` again to change the PIN or switch to another
account; it keeps exactly one.

## Usage

```sh
hkuvpn set-password   # once; asks for your account and Portal PIN
hkuvpn                # connect; Ctrl-C disconnects
```

`HKUVPN_SERVER` and `HKUVPN_PORT` override the configured values for a single
run.

Using the proxy:

```sh
# curl (socks5h = resolve hostnames through the VPN too)
curl -x socks5h://127.0.0.1:1080 https://example.hku.hk/

# git / most CLI tools
ALL_PROXY=socks5h://127.0.0.1:1080 git clone https://...
```

```
# ~/.ssh/config
Host *.hku.hk
  ProxyCommand nc -X 5 -x 127.0.0.1:1080 %h %p
```

For a browser, set a SOCKS5 proxy on `127.0.0.1:1080` with "proxy DNS" enabled,
ideally in a separate profile or via a per-domain rule.

## With mihomo (Clash)

If you already run mihomo, let it do the routing: HKU domains go to the
`hkuvpn` proxy, everything else is unaffected, and no application needs its own
proxy setting. Merge this into your config:

```yaml
proxies:
  - name: HKU-SOCKS5
    type: socks5
    server: 127.0.0.1
    port: 1080
    udp: false # ocproxy is TCP only

proxy-groups:
  # Falls back to DIRECT whenever hkuvpn is not running, so HKU's public
  # sites keep working without the VPN.
  - name: HKU
    type: fallback
    proxies:
      - HKU-SOCKS5
      - DIRECT
    url: https://www.gstatic.com/generate_204
    interval: 10
    timeout: 1500
    lazy: true

rules:
  # The VPN gateway itself must stay outside the tunnel. These have to come
  # before the hku.hk rule, or openconnect's own connection loops back into
  # the proxy it is trying to set up (this matters most in TUN mode).
  - DOMAIN,vpn2fa.hku.hk,DIRECT
  - DOMAIN,vpn2fa-a.hku.hk,DIRECT
  - DOMAIN,vpn2fa-b.hku.hk,DIRECT

  - DOMAIN-SUFFIX,hku.hk,HKU
  - DOMAIN-SUFFIX,hku.edu.hk,HKU
  # Campus hosts you reach by IP need their own rule, e.g.
  # - IP-CIDR,<lab subnet>,HKU,no-resolve
```

Two things to watch:

- Rules match top to bottom, so put these above any broader rule (`GEOIP`,
  `MATCH`, a catch-all for `.hk`) that would otherwise claim the traffic.
- If you have groups built with `include-all: true`, add
  `exclude-filter: '^HKU-SOCKS5$'` to them so the campus proxy is not picked as
  a general-purpose exit.

## Requirements

- A Secret Service keyring that is unlocked in your session (GNOME Keyring,
  KeePassXC, KWallet with the Secret Service interface, ...).
- HKU 2FA already enrolled.

## License

MIT
