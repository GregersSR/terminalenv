{ config, lib, ... }:

let
  runtimeFiles = lib.filter (line:
    line != "" && !lib.hasPrefix "#" line
  ) (lib.splitString "\n" (builtins.readFile ./runtime-files.txt));

  runtimeFileSet = lib.fileset.unions (map (path: ./. + "/${path}") runtimeFiles);

  repoSourceRoot = lib.fileset.toSource {
    root = ./.;
    fileset = runtimeFileSet;
  };

  runtimeLinkScript = lib.concatMapStrings (path: ''
    mkdir -p "$HOME/terminalenv/$(dirname "${path}")"
    if [ -e "$HOME/terminalenv/${path}" ] && [ ! -L "$HOME/terminalenv/${path}" ]; then
      errorEcho "Refusing to replace non-symlink runtime file: $HOME/terminalenv/${path}"
      exit 1
    fi
    ln -sfn "${repoSourceRoot}/${path}" "$HOME/terminalenv/${path}"
  '') runtimeFiles;
in

{
  imports = [ ./modules/symlinked-home-files.nix ];

  config = lib.mkMerge [
    {
      dotfiles.links.enable = lib.mkDefault true;
      dotfiles.links.mode = lib.mkDefault "out-of-store";
    }
    (lib.mkIf (config.dotfiles.links.enable && config.dotfiles.links.mode == "out-of-store" && config.dotfiles.links.repoRoot == "${config.home.homeDirectory}/terminalenv") {
      home.activation.dotfilesOutOfStoreCheck = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -d "$HOME/terminalenv/home" ]; then
          errorEcho "Out-of-store dotfiles mode requires a local checkout at $HOME/terminalenv. Use store mode for flake-only consumers, or override TERMENV in ~/.profile.local and set dotfiles.links.repoRoot to match."
          exit 1
        fi
      '';
    })
    (lib.mkIf (config.dotfiles.links.enable && config.dotfiles.links.mode == "store") {
      home.activation.dotfilesRuntimeFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -e "$HOME/terminalenv" ] && [ ! -d "$HOME/terminalenv" ]; then
          errorEcho "Refusing to replace non-directory runtime root: $HOME/terminalenv"
          exit 1
        fi

        mkdir -p "$HOME/terminalenv"
        ${runtimeLinkScript}
      '';
    })
  ];
}
