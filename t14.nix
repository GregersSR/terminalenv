{ config, pkgs, ownPkgs, ... }:

{
  home = {
    username = "gsr";
    homeDirectory = "/home/gsr";
    stateVersion = "24.11";
    packages = [
        ownPkgs.starship
        ownPkgs.repos
    ];
  };

  programs.gh.enable = true;
  programs.sagemath.enable = true;
}
