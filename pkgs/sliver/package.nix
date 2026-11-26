{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  # Sliver 1.7.9 hardcodes garble flags (-literals-shared, -literals-shared-short)
  # that only exist in its own fork, moloch--/garble, released as v<goversion>b and
  # built with that exact Go. garble demands the exact Go patch it was built with, so
  # pin go_1_27 (= 1.27.3) to match garble v1.27.3b. Bump both together with Sliver's
  # garbleVersion (util/assets/constants.go) and nixpkgs' matching go_1_NN.
  go_1_27,
}:
stdenv.mkDerivation rec {
  pname = "sliver";
  version = "1.7.9";

  # Fetch the client binary
  client = fetchurl {
    url = "https://github.com/BishopFox/sliver/releases/download/v${version}/sliver-client_linux-amd64";
    sha256 = "sha256-n2a9XVXsGQkFaIGEsCkDKg6MRU/4O3bJGIT2U4QgdnI=";
  };

  # Fetch the server binary
  server = fetchurl {
    url = "https://github.com/BishopFox/sliver/releases/download/v${version}/sliver-server_linux-amd64";
    sha256 = "sha256-bFTqlJYfFd4iu3ZZEbhQ0FTmb2kGnkt5mrfMMTTo7zY=";
  };

  # Sliver's garble fork, the exact binary Sliver would otherwise download itself
  # (util/assets/garble.go). Static Go binary — needs no patchelf. Pair it with
  # go_1_27 above. garbleVersion lives in Sliver's util/assets/constants.go.
  garble = fetchurl {
    url = "https://github.com/moloch--/garble/releases/download/v1.27.3b/garble_linux-amd64";
    sha256 = "sha256-5WJWB4WFwgRSUhWEphsgXeOEa8HjlxEmDV3aB3LXPFo=";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    go_1_27
  ];
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/libexec/sliver

    # Install client
    install -m755 ${client} $out/bin/sliver-client

    # Install server (unwrapped)
    install -m755 ${server} $out/bin/.sliver-server-unwrapped

    # Install Sliver's garble fork (static binary)
    install -m755 ${garble} $out/libexec/sliver/garble

    # Create wrapper for server that sets up Go environment.
    # sgn (shikata-ga-nai) isn't shipped separately; keep the pre-existing
    # behaviour of pointing it at the garble binary.
    makeWrapper $out/bin/.sliver-server-unwrapped $out/bin/sliver-server \
      --run 'mkdir -p $HOME/.sliver/go/bin' \
      --run 'ln -sf ${go_1_27}/bin/go $HOME/.sliver/go/bin/go' \
      --run 'ln -sf ${go_1_27}/bin/gofmt $HOME/.sliver/go/bin/gofmt' \
      --run 'ln -sf '"$out"'/libexec/sliver/garble $HOME/.sliver/go/bin/garble' \
      --run 'ln -sf '"$out"'/libexec/sliver/garble $HOME/.sliver/go/bin/sgn'

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
