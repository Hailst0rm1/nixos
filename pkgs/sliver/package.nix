{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  go_1_23,
  garble,
}:
stdenv.mkDerivation rec {
  pname = "sliver";
  version = "1.5.44";

  # Fetch the client binary
  client = fetchurl {
    url = "https://github.com/BishopFox/sliver/releases/download/v${version}/sliver-client_linux";
    sha256 = "1vsrh75as1vrk645bwnxwkr2y5y3wngrbjiz5bj4n9smh9n80wpk";
  };

  # Fetch the server binary
  server = fetchurl {
    url = "https://github.com/BishopFox/sliver/releases/download/v${version}/sliver-server_linux";
    sha256 = "0l614fx904vk768p4kwi4acs4kla3cryl5b2cv6ydgd16gvcpgdq";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    go_1_23
    garble
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # Install client
    install -m755 ${client} $out/bin/sliver-client

    # Install server (unwrapped)
    install -m755 ${server} $out/bin/.sliver-server-unwrapped

    # Create wrapper for server that sets up Go environment
    makeWrapper $out/bin/.sliver-server-unwrapped $out/bin/sliver-server \
      --run 'mkdir -p $HOME/.sliver/go/bin' \
      --run 'ln -sf ${go_1_23}/bin/go $HOME/.sliver/go/bin/go' \
      --run 'ln -sf ${go_1_23}/bin/gofmt $HOME/.sliver/go/bin/gofmt' \
      --run 'ln -sf ${garble}/bin/garble $HOME/.sliver/go/bin/garble' \
      --run 'ln -sf ${garble}/bin/garble $HOME/.sliver/go/bin/sgn'

    runHook postInstall
  '';

  meta = with lib; {
    description = "Adversary Emulation Framework";
    longDescription = ''
      Sliver is an open source cross-platform adversary emulation/red team framework.

      NOTE: This package contains pre-built binaries that are functional for running
      the Sliver client and server. However, implant generation (especially for Windows
      targets) requires additional cross-compilation toolchains (~500MB of assets).

      For full implant generation capabilities, use the sliver-generate wrapper which
      uses Docker to run generation commands with all necessary toolchains.
    '';
    homepage = "https://github.com/BishopFox/sliver";
    license = licenses.gpl3;
    maintainers = [];
    platforms = platforms.linux;
  };
}
