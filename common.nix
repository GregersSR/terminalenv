{ config, pkgs, localpkgs, ... }:

{

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Provide man pages for installed programs, but use system man.
  home.extraOutputsToInstall = [ "man" ];
  programs.man.enable = false;

  home.packages = [
    pkgs.cargo
    pkgs.gef
    pkgs.git-annex
    pkgs.jqp
    pkgs.git-filter-repo
    pkgs.pixi
  ];

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


  programs = {
    neovim = {
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

    bat.enable = true;
    eza = {
      enable = true;
      enableBashIntegration = false;
      enableZshIntegration = true;
    };

    zsh = {
      enable = true;
      oh-my-zsh = {
        enable = true;
        plugins = ["git"];
        theme = "sunrise";
      };
    };

    bash = {
      enable = true;
      bashrcExtra = ''
      [ -f ~/terminalenv/home/bash/bashrc ] && source ~/terminalenv/home/bash/bashrc 
      '';
      profileExtra = ''
      [ -f ~/terminalenv/home/profile ] && source ~/terminalenv/home/profile
      '';
    };

    git = {
      enable = true;
      settings = {
        core = {
          autocrlf = "input";
          editor = "nvim";
        };
        pull.ff = "only";
        init.defaultBranch = "main";
      };
    };

    ssh = {
      enable = true;
      hashKnownHosts = false;
      includes = [ "config.d/*" ];
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    difftastic = {
      enable = true;
      git.enable = true;
    };
  };
}
