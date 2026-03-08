{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  installShellFiles,
  writableTmpDirAsHomeHook,
  gitMinimal,
  nixosTests,
  buildPackages,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "starship";
  version = "1.24.2+14";

  src = fetchFromGitHub {
    owner = "starship";
    repo = "starship";
    rev = "0110bf59c86f6f0f33f95dc614c231acc19547b8";
    hash = "sha256-MjRkUnMA4SMRaZffosa+RuANr97KKlKBhJEnpaAE+rU=";
  };

  nativeBuildInputs = [ installShellFiles ];

  buildInputs = lib.optionals (stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64) [
    writableTmpDirAsHomeHook
  ];

  postInstall = ''
    presetdir=$out/share/starship/presets/
    mkdir -p $presetdir
    cp docs/public/presets/toml/*.toml $presetdir
  ''
  + lib.optionalString (stdenv.hostPlatform.emulatorAvailable buildPackages) (
    let
      emulator = stdenv.hostPlatform.emulator buildPackages;
    in
    ''
      installShellCompletion --cmd starship \
        --bash <(${emulator} $out/bin/starship completions bash) \
        --fish <(${emulator} $out/bin/starship completions fish) \
        --zsh <(${emulator} $out/bin/starship completions zsh)
    ''
  );

  cargoHash = "sha256-wgM42fcVU65mBkj8MjUDHHh9ocPyCACWbOgk07Ffa1E=";

  nativeCheckInputs = [
    gitMinimal
    writableTmpDirAsHomeHook
  ];

  passthru.tests = {
    inherit (nixosTests) starship;
  };

  meta = {
    description = "Minimal, blazing fast, and extremely customizable prompt for any shell";
    homepage = "https://starship.rs";
    downloadPage = "https://github.com/starship/starship";
    license = lib.licenses.isc;
    maintainers = with lib.maintainers; [
      danth
      Br1ght0ne
      Frostman
      da157
      sigmasquadron
    ];
    mainProgram = "starship";
  };
})
