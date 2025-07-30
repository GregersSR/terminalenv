{ config, pkgs, ... }:

{

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    pkgs.cargo
    pkgs.gef
    pkgs.git-annex
  ];

  home.shellAliases = {
    ll = "ls -lAgh";
    l = "ls -lgh";
    info = "info --vi-keys";
    grep = "grep --color=auto --exclude-dir={.git,.idea}";
    zgrep = "zgrep --color=always";
    cat = "bat";
    sum = "paste -sd+ | bc";
  };

  # sessionPath and sessionVariables only take effect in a new login session
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  home.sessionVariables = {
    CDPATH = "..";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    MANROFFOPT = "-c";
  };

  home.file = {
    ".local/bin/update-packages" = {
      source = ../scripts/update-packages.sh;
      executable = true;
    };
  };

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.neovim = {
    enable = true;
    vimAlias = true;
    defaultEditor = true;
    extraConfig = ''
    set number
    set relativenumber
    '';	
    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
      plenary-nvim
      diffview-nvim
      telescope-nvim
      neogit
    ];
  };

  programs.bat.enable = true;
  programs.eza.enable = true;

  programs.zsh = {
    enable = true;    
    oh-my-zsh = {
      enable = true;
      plugins = ["git"];
      theme = "sunrise";
    };
  };

  programs.git = {
    enable = true;
    extraConfig = {
      core = {
        autocrlf = "input";
	      editor = "nvim";
      };
      pull.ff = "only";
      init.defaultBranch = "main";
    };
    difftastic.enable = true;
  };

  programs.ssh = {
    enable = true;
    hashKnownHosts = false;
    includes = [ "config.d/*" ];
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
}
