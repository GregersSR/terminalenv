{ pkgs, homeManager, modules, nixpkgsFlake, ownPkgs }:

let
  repoRoot = ../.;

  allPackages = [ "home" "repos" "aitools" ];

  mkCheckActivation = mode:
    let
      isStore = mode == "store";
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

          dotfiles.links.storePackages = lib.mkForce (if isStore then allPackages else [ ]);
          dotfiles.links.outOfStorePackages = lib.mkForce (if isStore then [ ] else allPackages);
          dotfiles.links.repoRoot = lib.mkForce (builtins.toString repoRoot);
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
