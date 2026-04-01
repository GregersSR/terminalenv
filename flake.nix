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
      mkCheckActivation = mode: (home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          localpkgs = packages;
        };
        modules = [
          modules.common
          {
            home.username = "tester";
            home.homeDirectory = "/tmp/terminalenv-test-home";
            home.stateVersion = "24.11";

            dotfiles.links.mode = pkgs.lib.mkForce mode;
            dotfiles.links.repoRoot = pkgs.lib.mkForce (builtins.toString ./.);
          }
        ];
      }).activationPackage;
      deploymentTestImage = pkgs.dockerTools.buildImage {
        name = "terminalenv-deployment-tests";
        tag = "latest";
        copyToRoot = pkgs.buildEnv {
          name = "terminalenv-deployment-test-root";
          paths = with pkgs; [ bashInteractive coreutils git ];
          pathsToLink = [ "/bin" ];
        };
        config.Cmd = [ "/bin/bash" ];
      };
      deploymentTest = pkgs.writeShellApplication {
        name = "test-deployments";
        runtimeInputs = with pkgs; [ bash coreutils git nix podman ];
        text = ''
          exec ${pkgs.bash}/bin/bash ${./tests/test-deployments.sh} "$@"
        '';
      };
      deploymentCheck = pkgs.runCommandLocal "deployment-tests" {
        nativeBuildInputs = [ pkgs.bash pkgs.coreutils ];
        allowSubstitutes = false;
        preferLocalBuild = true;
      } ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"

        export ACTIVATION_OUT_OF_STORE="${mkCheckActivation "out-of-store"}"
        export ACTIVATION_STORE="${mkCheckActivation "store"}"
        export EXPECTED_OUT_OF_STORE_ROOT="${./.}"
        export REPO_ROOT="${./.}"

        ${pkgs.bash}/bin/bash ${./tests/test-deployments-in-nix-check.sh}
        touch "$out"
      '';
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
      apps.${system}.test-deployments = {
        type = "app";
        program = "${deploymentTest}/bin/test-deployments";
      };
      checks.${system}.deployment-tests = deploymentCheck;
      inherit modules;
    };
}
