{
  description = "Home Manager configuration of gsr";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      packages = import ./packages pkgs;
      extraSpecialArgs = {
        localpkgs = packages;
      };
      modules = {
        common = ./common.nix;
        dell-xps-15 = ./dell-xps-15.nix;
        t14 = ./t14.nix;
      };
    in {
      homeConfigurations."gsr" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        inherit extraSpecialArgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [ modules.common modules.t14 ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };
      inherit modules;
    };
}
