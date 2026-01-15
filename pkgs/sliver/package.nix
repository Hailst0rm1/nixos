{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  go,
  # TEMPORARY: Remove garble from function params due to nixpkgs 25.11 incompatibility
  # TODO: Restore this line when garble is fixed in nixpkgs:
  # garble,
}:
stdenv.mkDerivation rec {
  pname = "sliver";
  version = "1.6.4";

  # Fetch the client binary
  client = fetchurl {
    url = "https://github.com/BishopFox/sliver/releases/download/v${version}/sliver-client_linux-amd64";
    sha256 = "sha256-SKN/p0m/j44Pm1+bHCH5Yiv6yBT1g1qMhpY3xeM8+5A=";
  };

  # Fetch the server binary
  server = fetchurl {
    url = "https://github.com/BishopFox/sliver/releases/download/v${version}/sliver-server_linux-amd64";
    sha256 = "sha256-ZNMCOW3axCa4Recc1RQ6ZLWzTaHVwMRAhPF4buZR6m0=";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    go
    # TEMPORARY: Removed garble from buildInputs
    # TODO: Restore this line when garble is fixed in nixpkgs:
    # garble
  ];
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # Install client
    install -m755 ${client} $out/bin/sliver-client

    # Install server (unwrapped)
    install -m755 ${server} $out/bin/.sliver-server-unwrapped

    # TEMPORARY: Install pre-built garble binary from same directory
    # TODO: Remove this line when garble is fixed in nixpkgs
    install -m755 ${./garble} $out/bin/garble

    # Create wrapper for server that sets up Go environment
    makeWrapper $out/bin/.sliver-server-unwrapped $out/bin/sliver-server \
      --run 'mkdir -p $HOME/.sliver/go/bin' \
      --run 'ln -sf ${go}/bin/go $HOME/.sliver/go/bin/go' \
      --run 'ln -sf ${go}/bin/gofmt $HOME/.sliver/go/bin/gofmt' \
      --run 'ln -sf '"$out"'/bin/garble $HOME/.sliver/go/bin/garble' \
      --run 'ln -sf '"$out"'/bin/garble $HOME/.sliver/go/bin/sgn'
      # TEMPORARY: Changed to use $out/bin/garble instead of $\{garble}/bin/garble
      # TODO: Restore these lines when garble is fixed in nixpkgs:
      # --run 'ln -sf $\{garble}/bin/garble $HOME/.sliver/go/bin/garble' \
      # --run 'ln -sf $\{garble}/bin/sgn $HOME/.sliver/go/bin/sgn'

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
