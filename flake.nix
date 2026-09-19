{
  description = "Modbus TCP for iDM heat pumps with Navigator 2.0 control";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    {
      self,
      flake-utils,
      nixpkgs,
    }:
    let
      theseHpkgNames = [
        "idm-modbus"
      ];
      # The default set, so that the toolchain comes from the binary cache
      # instead of being compiled. Pinning a version costs hours here.
      hOverlay = selfn: supern: {
        haskell = supern.haskell // {
          packageOverrides =
            selfh: superh:
            supern.haskell.packageOverrides selfh superh
            // {
              idm-modbus = selfh.callCabal2nix "idm-modbus" ./. { };
            };
        };
      };
      overlays = [ hOverlay ];
      perSystem =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            inherit overlays;
          };
          hpkgs = pkgs.haskellPackages;
          theseHpkgs = nixpkgs.lib.genAttrs theseHpkgNames (n: hpkgs.${n});
        in
        {
          packages = theseHpkgs // {
            default = theseHpkgs.idm-modbus;
          };

          devShells.default = hpkgs.shellFor {
            packages = _: (builtins.attrValues theseHpkgs);
            nativeBuildInputs = with pkgs; [
              hpkgs.cabal-fmt
              hpkgs.cabal-install
              hpkgs.haskell-language-server
              ormolu
            ];
          };
        };
    in
    {
      overlays.default = nixpkgs.lib.composeManyExtensions overlays;
    }
    // flake-utils.lib.eachDefaultSystem perSystem;
}
