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

  outputs = { nixpkgs, home-manager, cli-tools, mypkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;
      repoPkgs = import ./packages pkgs;
      ownPkgs = cli-tools.packages.${system} // mypkgs.packages.${system} // repoPkgs;
      nixpkgsPin = import ./nixpkgs-registry.nix nixpkgs;
      modules = {
        dotfiles = ./dotfiles.nix;
        common = ./common.nix;
        t14 = import ./t14.nix ownPkgs;
      };
      deploymentTests = import ./tests/deployments.nix {
        inherit pkgs modules ownPkgs;
        nixpkgsFlake = nixpkgs;
        homeManager = home-manager;
      };
    in {
      homeConfigurations."gsr" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = with modules; [ 
          dotfiles
          common
          t14
          nixpkgsPin
        ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };
      apps.${system}.test-deployments = deploymentTests.test;
      packages.${system} = lib.removeAttrs ownPkgs [ "pythonPackages" ];
      checks.${system}.deployment-tests = deploymentTests.check;
      inherit modules;
    };
}
