{
  lib,
  stdenv,
  fetchurl,
}: let
  velociraptorRelease = "v0.77.2";
in
  # Upstream ships a statically linked musl binary; the GUI is embedded in it,
  # so building from source would pull in a full npm + Go toolchain for no gain.
  stdenv.mkDerivation {
    pname = "velociraptor";
    version = lib.removePrefix "v" velociraptorRelease;

    src = fetchurl {
      url = "https://github.com/Velocidex/velociraptor/releases/download/${velociraptorRelease}/velociraptor-${velociraptorRelease}-linux-amd64-musl";
      hash = "sha256-8//g7ZlCl1IUwbe6eiSyAer/StgnV1NCtDVEFYtkxSQ=";
    };

    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/velociraptor
      runHook postInstall
    '';

    meta = {
      description = "Endpoint visibility and collection tool (DFIR / threat hunting)";
      homepage = "https://github.com/Velocidex/velociraptor";
      license = lib.licenses.agpl3Only;
      platforms = ["x86_64-linux"];
      mainProgram = "velociraptor";
    };
  }
