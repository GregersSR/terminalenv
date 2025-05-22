{ pkgs ? import <nixpkgs> {}, ...}:
  pkgs.stdenv.mkDerivation {
    name = "usbreset";

    src = ./.;
    buildPhase = ''
      $CC usbreset.c -o usbreset
    '';

    installPhase = ''
      mkdir -p "$out/bin"
      install --mode=0775 usbreset "$out/bin/usbreset"
    '';
  }
