{
  lib,
  writeShellApplication,
  openconnect,
  ocproxy,
  expect,
  libsecret,
  # Build-time defaults; each can still be overridden at run time through
  # HKUVPN_SERVER and HKUVPN_PORT.
  server ? "vpn2fa.hku.hk",
  socksPort ? 1080,
}:

writeShellApplication {
  name = "hkuvpn";

  runtimeInputs = [
    openconnect
    ocproxy
    expect
    libsecret
  ];

  runtimeEnv = {
    HKUVPN_DEFAULT_SERVER = server;
    HKUVPN_DEFAULT_PORT = toString socksPort;
    HKUVPN_EXPECT_SCRIPT = "${./hkuvpn.exp}";
  };

  text = builtins.readFile ./hkuvpn.sh;

  meta = {
    description = "Connect to HKUVPN through a local SOCKS5 proxy, without a tun device";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "hkuvpn";
  };
}
