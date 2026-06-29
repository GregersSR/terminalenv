{ pkgs, homeManager, modules, nixpkgsFlake, ownPkgs, dotpkgs }:

let
  lib = pkgs.lib;
  repoRoot = ../.;
  dotpkgsRoot = "${builtins.toString repoRoot}/dotpkgs";

  mkCheckActivation = mode:
    let
      isStore = mode == "store";
      packages = if isStore
        then dotpkgs
        else lib.mapAttrs (n: _: "${dotpkgsRoot}/${n}") dotpkgs;
    in
    (homeManager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {
        inherit nixpkgsFlake;
        inherit ownPkgs;
      };
      modules = [
        modules.dotfiles
        modules.common
        ({ lib, ... }: {
          home.username = "tester";
          home.homeDirectory = "/tmp/terminalenv-test-home";
          home.stateVersion = "24.11";

          dotfiles.packages = lib.mkForce packages;
        })
      ];
    }).activationPackage;

  testPackage = pkgs.writeShellApplication {
    name = "test-deployments";
    runtimeInputs = with pkgs; [ bash coreutils podman ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${repoRoot}/tests/test-deployments.sh "$@"
    '';
  };

  check = pkgs.runCommandLocal "deployment-tests" {
    nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.stow ];
    allowSubstitutes = false;
    preferLocalBuild = true;
  } ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"

    export ACTIVATION_OUT_OF_STORE="${mkCheckActivation "out-of-store"}"
    export ACTIVATION_STORE="${mkCheckActivation "store"}"

    ${pkgs.bash}/bin/bash ${repoRoot}/tests/test-deployments-in-nix-check.sh
    touch "$out"
  '';
in {
  test = {
    type = "app";
    program = "${testPackage}/bin/test-deployments";
  };

  inherit check;
}
