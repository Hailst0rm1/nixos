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
  version = "0.32.2";

  binary = fetchurl {
    url = "https://github.com/vercel-labs/agent-browser/releases/download/v${version}/agent-browser-linux-x64";
    hash = "sha256-ZmoRKS/xr7KBwCMhL2YguX+BAmy7SY4xTc+vZ+CpKck=";
  };

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-browser";
    tag = "v${version}";
    hash = "sha256-d4eocgiBoNe7iCBl5cBHwglbyPAqLo11V3T5yZd9EUI=";
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
