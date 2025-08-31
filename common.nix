{ config, pkgs, ... }:

{

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    pkgs.cargo
    pkgs.gef
    pkgs.git-annex
  ];

  # sessionPath and sessionVariables only take effect in a new login session
  home.file = {
    ".local/bin/update-packages" = {
      source = ./scripts/update-packages.sh;
      executable = true;
    };
  };

  home.shell = {
    enableBashIntegration = true;
    enableZshIntegration = true;
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
    source $TERMENV/home/nvim/settings.vim
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
  programs.eza = {
    enable = true;
    enableBashIntegration = false;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;    
    oh-my-zsh = {
      enable = true;
      plugins = ["git"];
      theme = "sunrise";
    };
  };

  programs.bash = {
    enable = true;
    bashrcExtra = ''
    [ -f ~/terminalenv/home/bash/bashrc ] && source ~/terminalenv/home/bash/bashrc 
    '';
    profileExtra = ''
    [ -f ~/terminalenv/home/profile ] && source ~/terminalenv/home/profile
    '';
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
    nix-direnv.enable = true;
  };
}
