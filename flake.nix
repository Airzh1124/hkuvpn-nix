{
  description = "HKUVPN without a tun device: openconnect + ocproxy as a local SOCKS5 proxy";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        hkuvpn = pkgs.callPackage ./package.nix { };
        default = hkuvpn;
      });

      overlays.default = final: _prev: {
        hkuvpn = final.callPackage ./package.nix { };
      };

      # Same options (`programs.hkuvpn.*`) for both module systems.
      nixosModules.default = import ./module.nix { homeManager = false; };
      homeModules.default = import ./module.nix { homeManager = true; };

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
