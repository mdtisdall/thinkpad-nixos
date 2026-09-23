{
  description = "NixOS configuration for the ThinkPad T14s Gen 3";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Tracks Claude Code releases much faster than nixpkgs does.
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      disko,
      lanzaboote,
      claude-code,
      ...
    }:
    let
      # Systems that edit and check this repository: the Mac and ersatz itself.
      devSystems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forDevSystems = nixpkgs.lib.genAttrs devSystems;
    in
    {
      # Tools for scripts/check and the dev-workflow (gh uses this repo's own token).
      devShells = forDevSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              pkgs.gh
              pkgs.nixfmt
              pkgs.statix
              pkgs.deadnix
            ];
          };
        }
      );

      nixosConfigurations.ersatz = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          lanzaboote.nixosModules.lanzaboote
          ./hosts/ersatz/disko.nix
          ./hosts/ersatz/hardware-configuration.nix
          ./hosts/ersatz/configuration.nix
          { nixpkgs.overlays = [ claude-code.overlays.default ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.dylan = import ./home;
          }
        ];
      };
    };
}
