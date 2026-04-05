{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.links;
  homeRoot = ./home;
  homeFiles = lib.filesystem.listFilesRecursive homeRoot;

  relativeHomePath = path:
    lib.removePrefix "${toString homeRoot}/" (toString path);

  decodeStowSegment = segment:
    if lib.hasPrefix "dot-" segment then
      ".${lib.removePrefix "dot-" segment}"
    else
      segment;

  decodeStowPath = relativePath:
    lib.concatStringsSep "/" (map decodeStowSegment (lib.splitString "/" relativePath));

  storeManagedFiles = lib.listToAttrs (map (path: {
    name = decodeStowPath (relativeHomePath path);
    value = {
      source = path;
    };
  }) homeFiles);

  repoRootArg = lib.escapeShellArg cfg.repoRoot;
  repoHomeArg = lib.escapeShellArg "${cfg.repoRoot}/home";
in {
  options.dotfiles.links = {
    enable = lib.mkEnableOption "dotfiles deployment";

    mode = lib.mkOption {
      type = lib.types.enum [ "store" "out-of-store" ];
      default = "store";
      description = ''
        Whether Home Manager should materialize files from the dotfiles tree in
        the Nix store or restow them from a local checkout.
      '';
    };

    repoRoot = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/terminalenv";
      example = "${config.home.homeDirectory}/src/dotfiles";
      description = ''
        Checkout path used when link mode is `out-of-store`.
      '';
    };
  };

  config = lib.mkMerge [
    {
      dotfiles.links.enable = lib.mkDefault true;
      dotfiles.links.mode = lib.mkDefault "out-of-store";
    }
    (lib.mkIf (cfg.enable && cfg.mode == "store") {
      home.file = storeManagedFiles;

      home.activation.dotfilesUnstow = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        if [ -d ${repoHomeArg} ]; then
          ${pkgs.stow}/bin/stow --dir ${repoRootArg} --target "$HOME" --dotfiles --no-folding --delete home
        fi
      '';
    })
    (lib.mkIf (cfg.enable && cfg.mode == "out-of-store") {
      home.activation.dotfilesRestow = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ ! -d ${repoHomeArg} ]; then
          errorEcho "Out-of-store dotfiles mode requires a local checkout at ${cfg.repoRoot}."
          exit 1
        fi

        ${pkgs.stow}/bin/stow --dir ${repoRootArg} --target "$HOME" --dotfiles --no-folding --restow home
      '';
    })
  ];
}
