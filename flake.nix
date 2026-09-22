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
  };

  outputs = { self, nixpkgs, home-manager, disko, ... }: {
    nixosConfigurations.thinkpad-t14s = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./hosts/thinkpad-t14s/disko.nix
        ./hosts/thinkpad-t14s/hardware-configuration.nix
        ./hosts/thinkpad-t14s/configuration.nix
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
