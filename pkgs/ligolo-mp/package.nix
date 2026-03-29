{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  # TEMPORARY: Remove function params due to nixpkgs 25.11 incompatibility
  # TODO: Restore these lines when garble is fixed in nixpkgs:
  # go,
  # garble,
}: let
  # TEMPORARY: Bundle Go 1.25.7 specifically for garble compatibility
  # TODO: Remove this entire go_1_25 derivation when garble is fixed in nixpkgs
  go_1_25 = stdenv.mkDerivation rec {
    pname = "go";
    version = "1.25.7";

    src = fetchurl {
      url = "https://go.dev/dl/go${version}.linux-amd64.tar.gz";
      sha256 = "sha256-EubWoZEJGuJ9wx9u/GMOOjuLpAm681c9lVsZb98IYAU=";
    };

    nativeBuildInputs = [autoPatchelfHook];

    dontBuild = true;

    # Test data ELFs reference libs not available in the sandbox
    autoPatchelfIgnoreMissingDeps = ["libtiff.so.6" "libstdc++.so.6"];

    installPhase = ''
      mkdir -p $out
      cp -r * $out/
    '';

    passthru = {
      GOOS = "linux";
      GOARCH = "amd64";
      CGO_ENABLED = true;
    };
  };
in
  stdenv.mkDerivation rec {
    pname = "ligolo-mp";
    version = "2.2.1";

    src = fetchurl {
      url = "https://github.com/ttpreport/ligolo-mp/releases/download/v${version}/ligolo-mp_linux_amd64";
      sha256 = "sha256-f+/0CyWGyE7JVPMOl24rVfJHNYGhnUAUPnu8vYU3d5Y=";
    };

    dontUnpack = true;

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
    ];

    buildInputs = [
      go_1_25
      # TEMPORARY: Removed garble from buildInputs
      # TODO: Restore this line when garble is fixed in nixpkgs:
      # garble
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      mkdir -p $out/libexec/ligolo-mp

      # Install binary (unwrapped)
      install -m755 ${src} $out/bin/.ligolo-mp-unwrapped

      # TEMPORARY: Install pre-built garble binary to libexec (not in PATH)
      # TODO: Remove this line when garble is fixed in nixpkgs
      install -m755 ${./garble} $out/libexec/ligolo-mp/garble

      # Create wrapper that sets up Go environment
      makeWrapper $out/bin/.ligolo-mp-unwrapped $out/bin/ligolo-mp \
        --run 'mkdir -p $HOME/.ligolo-mp-server/assets/go/bin' \
        --run 'ln -sf ${go_1_25}/bin/go $HOME/.ligolo-mp-server/assets/go/bin/go' \
        --run 'ln -sf ${go_1_25}/bin/gofmt $HOME/.ligolo-mp-server/assets/go/bin/gofmt' \
        --run 'ln -sf '"$out"'/libexec/ligolo-mp/garble $HOME/.ligolo-mp-server/assets/go/bin/garble' \
        --run 'ln -sf '"$out"'/libexec/ligolo-mp/garble $HOME/.ligolo-mp-server/assets/go/bin/sgn'
        # TEMPORARY: Changed to use $out/bin/garble and go_1_25 instead of nixpkgs versions
        # TODO: Restore these lines when garble is fixed in nixpkgs:
        # --run 'ln -sf $\{go}/bin/go $HOME/.ligolo-mp-server/assets/go/bin/go' \
        # --run 'ln -sf $\{go}/bin/gofmt $HOME/.ligolo-mp-server/assets/go/bin/gofmt' \
        # --run 'ln -sf $\{garble}/bin/garble $HOME/.ligolo-mp-server/assets/go/bin/garble' \
        # --run 'ln -sf $\{garble}/bin/garble $HOME/.ligolo-mp-server/assets/go/bin/sgn'

      runHook postInstall
    '';

    meta = with lib; {
      description = "Tunneling/pivoting tool that uses a TUN interface (multiplayer + tui)";
      longDescription = ''
        Ligolo-mp is a multiplayer version of ligolo-ng, a tunneling and pivoting tool
        that uses a TUN interface for network operations with a terminal UI.

        This package uses Go 1.25 for compatibility with garble obfuscation.
      '';
      homepage = "https://github.com/ttpreport/ligolo-mp";
      license = licenses.gpl3;
      maintainers = [];
      platforms = platforms.linux;
    };
  }
