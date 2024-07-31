{ config, pkgs, ... }:

{

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
    pkgs.cargo
    pkgs.gef
  ];

  home.shellAliases = {
    ll = "ls -lAh";
    info = "info --vi-keys";
    grep = "grep --color=auto --exclude-dir={.git,.idea}";
    cat = "bat";
    sum = "paste -sd+ | bc";
    gdb = "gef";
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
      source = ./scripts/update-packages.sh;
      executable = true;
    };
  };

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  xdg = {
    enable = true;
    configFile = {
      nvim.source = ./config/nvim;
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.neovim = {
    enable = true;
    vimAlias = true;
    defaultEditor = true;
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
}
