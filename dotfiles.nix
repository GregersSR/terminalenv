{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.links;
  packageRoot = name: ./. + "/${name}";
  selectedPackages = map (name: {
    inherit name;
    root = packageRoot name;
  }) cfg.packages;
  selectedPackageFiles = lib.concatMap (pkg:
    map (path: {
      inherit (pkg) name;
      relativePath = lib.removePrefix "${toString pkg.root}/" (toString path);
      inherit path;
    }) (lib.filesystem.listFilesRecursive pkg.root)
  ) selectedPackages;
  decodeStowSegment = segment:
    if lib.hasPrefix "dot-" segment then
      ".${lib.removePrefix "dot-" segment}"
    else
      segment;
  decodeStowPath = relativePath:
    lib.concatStringsSep "/" (map decodeStowSegment (lib.splitString "/" relativePath));
  stowFlags = pkg:
    if pkg.name == "repos" then
      "--dotfiles --no-folding "
    else
      "";
  unstowCommands = lib.concatMapStringsSep "\n" (pkg:
    ''${pkgs.stow}/bin/stow ${stowFlags pkg}--dir ${repoRootArg} --target "$HOME" --delete ${lib.escapeShellArg pkg.name}''
  ) selectedPackages;
  restowCommands = lib.concatMapStringsSep "\n" (pkg:
    ''${pkgs.stow}/bin/stow ${stowFlags pkg}--dir ${repoRootArg} --target "$HOME" --restow ${lib.escapeShellArg pkg.name}''
  ) selectedPackages;

  storeManagedFiles = lib.listToAttrs (map (file: {
    name = decodeStowPath file.relativePath;
    value = {
      source = file.path;
    };
  }) selectedPackageFiles);

  repoRootArg = lib.escapeShellArg cfg.repoRoot;
  repoPackageCheck = lib.concatMapStringsSep "\n" (pkg: ''
    if [ ! -d ${lib.escapeShellArg "${cfg.repoRoot}/${pkg.name}"} ]; then
      errorEcho "Dotfiles package directory not found: ${cfg.repoRoot}/${pkg.name}"
      exit 1
    fi
  '') selectedPackages;
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

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "home" "repos" ];
      description = ''
        Top-level stow packages to deploy.
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
        if [ -d ${repoRootArg} ]; then
          ${unstowCommands}
        fi
      '';
    })
    (lib.mkIf (cfg.enable && cfg.mode == "out-of-store") {
      home.activation.dotfilesRestow = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ ! -d ${repoRootArg} ]; then
          errorEcho "Out-of-store dotfiles mode requires a local checkout at ${cfg.repoRoot}."
          exit 1
        fi

        ${repoPackageCheck}

        ${restowCommands}
      '';
    })
  ];
}
