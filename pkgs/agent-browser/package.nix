{
  lib,
  stdenv,
  fetchurl,
  fetchFromGitHub,
  autoPatchelfHook,
  makeWrapper,
  which,
  nix-update-script,
}: let
  version = "0.27.3";

  binary = fetchurl {
    url = "https://github.com/vercel-labs/agent-browser/releases/download/v${version}/agent-browser-linux-x64";
    hash = "sha256-Nz8BDi+RXAJvKlC3nwZ2uN6s6TNyr0O4LOIKdzd2Q1M=";
  };

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-browser";
    tag = "v${version}";
    hash = "sha256-XDTGYcDodP4hQ7fx3dAV2FYhHKIqLuiGz6+gPfgp8Rg=";
  };
in
  stdenv.mkDerivation {
    pname = "agent-browser";
    inherit version;

    dontUnpack = true;

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
    ];

    buildInputs = [stdenv.cc.cc.lib];

    installPhase = ''
      runHook preInstall

      install -Dm755 ${binary} $out/bin/agent-browser
      cp -r ${src}/skills $out/skills
      cp -r ${src}/skill-data $out/skill-data

      wrapProgram $out/bin/agent-browser \
        --prefix PATH : ${lib.makeBinPath [which]}

      runHook postInstall
    '';

    passthru.updateScript = nix-update-script {};

    meta = {
      description = "Headless browser automation CLI for AI agents (upstream prebuilt binary)";
      homepage = "https://github.com/vercel-labs/agent-browser";
      license = lib.licenses.asl20;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      platforms = ["x86_64-linux"];
      mainProgram = "agent-browser";
    };
  }
