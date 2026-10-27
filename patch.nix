{ system, pkgs }:

let
  # src is a source directory or a derivation. Name is the name of the resulting derivation. Patchspecs have url and hash.
  patch =
    { src, name, patchspecs }:
      pkgs.applyPatches {
        inherit src;
        inherit name;
        patches = map pkgs.fetchpatch2 patchspecs;
      };
  patch-drv = patchargs:
    import (patch patchargs) { inherit (pkgs.stdenv) system; };
  
in
  {
    inherit patch;
    inherit patch-drv;
    patch-nixpkgs = { name ? "nixpkgs-patched", patchspecs}:
      patch-drv { src = pkgs; inherit name; inherit patchspecs; };
  }
