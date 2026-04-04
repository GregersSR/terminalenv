{ config, pkgs, localpkgs, ... }:

{
  home = {
    username = "gsr";
    homeDirectory = "/home/gsr";
    stateVersion = "24.11";
    packages = [
        localpkgs.starship
    ];
  };

  programs.git.settings.user = {
    name = "Gregers Rørdam";
    email = "gregers@rordam.dk";
  };

  programs.gh.enable = true;
  programs.sagemath.enable = true;
}
