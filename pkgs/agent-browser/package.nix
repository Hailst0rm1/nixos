{
  lib,
  stdenv,
  fetchurl,
  fetchFromGitHub,
  autoPatchelfHook,
  makeWrapper,
  which,
  chromium,
  nix-update-script,
}: let
  version = "0.34.0";

  binary = fetchurl {
    url = "https://github.com/vercel-labs/agent-browser/releases/download/v${version}/agent-browser-linux-x64";
    hash = "sha256-aerfXY1gA6BqXNL5FOuyYcd1T+EzWpGQEiwzTpGQl4k=";
  };

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-browser";
    tag = "v${version}";
    hash = "sha256-UdCBSe7w0ZgJimB7ixGcaabJjH3m6O0vB1SV9n9apfE=";
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

      # `agent-browser install` downloads Chrome-for-Testing, which cannot run on
      # NixOS (`libglib-2.0.so.0: cannot open shared object file`). Default to
      # nixpkgs chromium instead so auto-launch works out of the box; --set-default
      # keeps an explicit AGENT_BROWSER_EXECUTABLE_PATH override working.
      wrapProgram $out/bin/agent-browser \
        --prefix PATH : ${lib.makeBinPath [which]} \
        --set-default AGENT_BROWSER_EXECUTABLE_PATH ${lib.getExe chromium}

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
