{ homeManager }:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.hkuvpn;
in
{
  options.programs.hkuvpn = {
    enable = lib.mkEnableOption "the hkuvpn command (HKUVPN through a local SOCKS5 proxy)";

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "youruid@connect.hku.hk";
      description = ''
        HKU account to connect as. When null, the `HKU_USER` environment
        variable must be set at run time.
      '';
    };

    server = lib.mkOption {
      type = lib.types.str;
      default = "vpn2fa.hku.hk";
      description = "VPN gateway to connect to.";
    };

    socksPort = lib.mkOption {
      type = lib.types.port;
      default = 1080;
      description = "Local port (on 127.0.0.1) the SOCKS5 proxy listens on.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "The hkuvpn package built with the options above.";
    };
  };

  config = lib.mkMerge [
    {
      programs.hkuvpn.package = pkgs.callPackage ./package.nix {
        inherit (cfg) user server socksPort;
      };
    }
    (lib.mkIf cfg.enable (
      if homeManager then
        { home.packages = [ cfg.package ]; }
      else
        { environment.systemPackages = [ cfg.package ]; }
    ))
  ];
}
