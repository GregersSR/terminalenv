{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.packages;

  storeEntries = lib.filterAttrs (_: v: builtins.isPath v) cfg;
  fsEntries    = lib.filterAttrs (_: v: builtins.isString v) cfg;

  storeFiles = lib.concatMap (name:
    let root = storeEntries.${name};
    in map (path: {
      relativePath = lib.removePrefix "${toString root}/" (toString path);
      inherit path;
    }) (lib.filesystem.listFilesRecursive root)
  ) (lib.attrNames storeEntries);

  storeManagedFiles = lib.listToAttrs (map (file: {
    name = file.relativePath;
    value = { source = file.path; };
  }) storeFiles);

  fsChecks = lib.concatMapStringsSep "\n" (name:
    let dir = builtins.dirOf fsEntries.${name};
    in ''
      if [ ! -d ${lib.escapeShellArg dir}/${lib.escapeShellArg name} ]; then
        errorEcho "Dotfiles package not found: ${dir}/${name}"
        exit 1
      fi
    ''
  ) (lib.attrNames fsEntries);

  stowRestow = lib.concatMapStringsSep "\n" (name:
    let dir = builtins.dirOf fsEntries.${name};
    in ''${pkgs.stow}/bin/stow --dir ${lib.escapeShellArg dir} --target "$HOME" --restow ${lib.escapeShellArg name}''
  ) (lib.attrNames fsEntries);

  stowUnstow = lib.concatMapStringsSep "\n" (name:
    let dir = builtins.dirOf fsEntries.${name};
    in ''
      if [ -d ${lib.escapeShellArg dir}/${lib.escapeShellArg name} ]; then
        ${pkgs.stow}/bin/stow --dir ${lib.escapeShellArg dir} --target "$HOME" --delete ${lib.escapeShellArg name} 2>/dev/null || true
      fi
    ''
  ) (lib.attrNames fsEntries);

in {
  options.dotfiles.packages = lib.mkOption {
    type = lib.types.attrsOf (lib.types.either lib.types.str lib.types.path);
    default = {};
    description = ''
      Dotfiles packages to deploy. Nix paths (e.g. dotpkgs.home from the
      flake output) are deployed as absolute symlinks via home.file from the
      Nix store. String filesystem paths (e.g. "/path/to/dotpkgs/name") are
      deployed via stow: the key is the stow package name, the string is the
      full package directory path (parent becomes the stow --dir).
    '';
  };

  config = lib.mkMerge [
    (lib.mkIf (storeEntries != {}) {
      home.file = storeManagedFiles;
    })

    (lib.mkIf (fsEntries != {}) {
      home.activation.dotfilesUnstow = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        ${stowUnstow}
      '';

      home.activation.dotfilesRestow = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        ${fsChecks}
        ${stowRestow}
      '';
    })
  ];
}
