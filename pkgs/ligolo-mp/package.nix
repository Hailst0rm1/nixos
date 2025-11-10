{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  go_1_23,
  garble,
}:
stdenv.mkDerivation rec {
  pname = "ligolo-mp";
  version = "2.1.0";

  src = fetchurl {
    url = "https://github.com/ttpreport/ligolo-mp/releases/download/v${version}/ligolo-mp_linux_amd64";
    sha256 = "sha256-W4k2ExJk5P4pjNvvmBilrL++3Haz9LMxbWKRWEsnYaI=";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    go_1_23
    garble
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # Install binary (unwrapped)
    install -m755 ${src} $out/bin/.ligolo-mp-unwrapped

    # Create wrapper that sets up Go environment
    makeWrapper $out/bin/.ligolo-mp-unwrapped $out/bin/ligolo-mp \
      --run 'mkdir -p $HOME/.ligolo-mp-server/assets/go/bin' \
      --run 'ln -sf ${go_1_23}/bin/go $HOME/.ligolo-mp-server/assets/go/bin/go' \
      --run 'ln -sf ${go_1_23}/bin/gofmt $HOME/.ligolo-mp-server/assets/go/bin/gofmt' \
      --run 'ln -sf ${garble}/bin/garble $HOME/.ligolo-mp-server/assets/go/bin/garble' \
      --run 'ln -sf ${garble}/bin/garble $HOME/.ligolo-mp-server/assets/go/bin/sgn'

    runHook postInstall
  '';

  meta = with lib; {
    description = "Tunneling/pivoting tool that uses a TUN interface (multiplayer + tui)";
    longDescription = ''
      Ligolo-mp is a multiplayer version of ligolo-ng, a tunneling and pivoting tool
      that uses a TUN interface for network operations with a terminal UI.

      This package uses Go 1.23 for compatibility with garble obfuscation.
    '';
    homepage = "https://github.com/ttpreport/ligolo-mp";
    license = licenses.gpl3;
    maintainers = [];
    platforms = platforms.linux;
  };
}
