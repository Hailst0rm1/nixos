{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
stdenv.mkDerivation rec {
  pname = "dll-proxy-generator";
  version = "0.1.1";

  src = fetchurl {
    url = "https://github.com/namazso/dll-proxy-generator/releases/download/${version}/dll-proxy-generator";
    sha256 = "0hjm80abjasz76ha9c72hxji619ixnjlzcwhbwxp0dm7l6wmk4sw";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m755 ${src} $out/bin/dll-proxy-generator

    runHook postInstall
  '';

  meta = with lib; {
    description = "Generate a proxy dll for arbitrary dll";
    longDescription = ''
      DLL Proxy Generator is a tool to generate a proxy dll for arbitrary dll,
      while also loading a user-defined secondary dll. This is useful for DLL
      hijacking and persistence techniques in penetration testing scenarios.
    '';
    homepage = "https://github.com/namazso/dll-proxy-generator";
    license = licenses.bsd0;
    maintainers = [];
    platforms = platforms.linux;
    mainProgram = "dll-proxy-generator";
  };
}
