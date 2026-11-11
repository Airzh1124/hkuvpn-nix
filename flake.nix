{
  description = "HKUVPN without a tun device: openconnect + ocproxy as a local SOCKS5 proxy";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
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

      # `nix flake check` builds the package (which runs shellcheck) and
      # evaluates both modules. Each module is evaluated against a stub of the
      # one option it sets, so the flake needs no home-manager input.
      checks = forAllSystems (
        pkgs:
        let
          evalModule =
            module: installPath:
            let
              inherit
                (lib.evalModules {
                  modules = [
                    module
                    {
                      options = lib.setAttrByPath installPath (
                        lib.mkOption { type = lib.types.listOf lib.types.package; }
                      );
                      config = {
                        _module.args.pkgs = pkgs;
                        programs.hkuvpn = {
                          enable = true;
                          socksPort = 1081;
                        };
                      };
                    }
                  ];
                })
                config
                ;
              inherit (config.programs.hkuvpn) package;
            in
            assert lib.elem package (lib.getAttrFromPath installPath config);
            assert lib.hasInfix "HKUVPN_DEFAULT_PORT=1081" package.text;
            package;
        in
        {
          package = self.packages.${pkgs.stdenv.hostPlatform.system}.hkuvpn;
          nixos-module = evalModule self.nixosModules.default [
            "environment"
            "systemPackages"
          ];
          home-module = evalModule self.homeModules.default [
            "home"
            "packages"
          ];
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
