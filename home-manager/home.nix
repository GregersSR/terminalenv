{ config, pkgs, ... }:

{
  home = {
    username = "gsr";
    homeDirectory = "/home/gsr";
    stateVersion = "23.11";
  };

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
  ];

  home.file = {
      ".config/nvim".source = ../config/nvim;
  };

  home.shellAliases = {
    ll = "ls -lAh";
    info = "info --vi-keys";
    grep = "grep --color=auto --exclude-dir={.git,.idea}";
    cat = "bat";
    sum = "paste -sd+ | bc";
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/gsr/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    CDPATH = "..";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.neovim = {
    enable = true;
    vimAlias = true;
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
    userName = "Gregers Rørdam";
    userEmail = "gregers@rordam.dk";
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
    includes = [ ".ssh/config.d/*" ];
  };
}
