{
  lib,
  stdenvNoCC,
  fetchurl,
}:
# The `@higgsfield/cli` npm package is only a launcher — its postinstall
# downloads the real `hf` Go binary from the GitHub release. We skip the npm
# shim and package that prebuilt binary directly (statically linked, no
# patchelf needed). Aliases `higgsfield`/`higgs` match the npm wrapper's names.
# Auth is interactive (`higgsfield auth login`), so no sops wrapper is needed.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "higgsfield-cli";
  version = "1.1.19";

  src = fetchurl {
    url = "https://github.com/higgsfield-ai/cli/releases/download/v${finalAttrs.version}/hf_${finalAttrs.version}_linux_amd64.tar.gz";
    hash = "sha256-0iH7o8lb7K0jgTnukfMK8hCSEqrO2eoZDLb43Req4YE=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 hf $out/bin/hf
    ln -s hf $out/bin/higgsfield
    ln -s hf $out/bin/higgs
    runHook postInstall
  '';

  meta = {
    description = "Higgsfield AI CLI — generate images and videos from the terminal";
    homepage = "https://higgsfield.ai";
    mainProgram = "higgsfield";
    platforms = ["x86_64-linux"];
  };
})
