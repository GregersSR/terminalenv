{
  description = "Home Manager configuration of gsr";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cli-tools = {
      url = "github:GregersSR/cli-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mypkgs = {
      url = "github:GregersSR/mypkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { cli-tools, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      repoPkgs = import ./packages pkgs;
      ownPkgs = cli-tools.packages.${system} // repoPkgs;
      extraSpecialArgs = {
        inherit ownPkgs;
        nixpkgsFlake = nixpkgs;
      };
      modules = {
        dotfiles = ./dotfiles.nix;
        common = ./common.nix;
        nixpkgs-registry = ./nixpkgs-registry.nix;
        t14 = ./t14.nix;
      };
      deploymentTests = import ./tests/deployments.nix {
        inherit pkgs modules ownPkgs;
        nixpkgsFlake = nixpkgs;
        homeManager = home-manager;
      };
    in {
      homeConfigurations."gsr" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        inherit extraSpecialArgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [ modules.dotfiles modules.common modules.nixpkgs-registry modules.t14 ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };
      apps.${system}.test-deployments = deploymentTests.test;
      packages.${system} = ownPkgs;
      checks.${system}.deployment-tests = deploymentTests.check;
      inherit modules;
    };
}
