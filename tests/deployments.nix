{ pkgs, homeManager, packages, modules }:

let
  repoRoot = ../.;

  mkCheckActivation = mode:
    (homeManager.lib.homeManagerConfiguration {
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
          dotfiles.links.repoRoot = pkgs.lib.mkForce (builtins.toString repoRoot);
        }
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
    nativeBuildInputs = [ pkgs.bash pkgs.coreutils ];
    allowSubstitutes = false;
    preferLocalBuild = true;
  } ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"

    export ACTIVATION_OUT_OF_STORE="${mkCheckActivation "out-of-store"}"
    export ACTIVATION_STORE="${mkCheckActivation "store"}"
    export EXPECTED_OUT_OF_STORE_ROOT="${repoRoot}"

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
