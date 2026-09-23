{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  python3,
}: let
  # python3 with the only third-party import the build scripts use (PyYAML).
  # vbox-adapter-check.py additionally needs PyGObject + libnotify; it is a
  # desktop-notification convenience we do not wrap (our own host/vm-network.sh
  # enforces the isolation invariant). The .py is still shipped under share/.
  pyEnv = python3.withPackages (ps: [ps.pyyaml]);

  # Wrapped entry points. Each shells out to `VBoxManage`, which is provided at
  # runtime by the enabled VirtualBox host module (cyber.dfir.enable) — so we
  # deliberately do NOT bake the unfree `virtualbox` into this closure, keeping
  # the package free and buildable in isolation.
  scripts = {
    vbox-build-flare-vm = "vbox-build-flare-vm.py";
    vbox-build-remnux = "vbox-build-remnux.py";
    vbox-clean-snapshots = "vbox-clean-snapshots.py";
    vbox-export-snapshot = "vbox-export-snapshot.py";
  };
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "flare-vbox";
    version = "vbox-1.0.0";

    src = fetchFromGitHub {
      owner = "mandiant";
      repo = "flare-vm";
      rev = finalAttrs.version;
      hash = "sha256-93EU+Ypp7YmzAVbksXdB9thzSUOKXKApJXyTSkB18vk=";
    };

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      runHook preInstall

      # Ship the upstream virtualbox/ scripts verbatim (incl. vboxcommon.py,
      # adapter-check, and the example configs/) on PYTHONPATH.
      mkdir -p $out/share/flare-vbox
      cp -r virtualbox/. $out/share/flare-vbox/

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (bin: file: ''
          makeWrapper ${pyEnv}/bin/python3 $out/bin/${bin} \
            --add-flags $out/share/flare-vbox/${file} \
            --prefix PYTHONPATH : $out/share/flare-vbox
        '')
        scripts)}

      runHook postInstall
    '';

    meta = {
      description = "Mandiant FLARE-VM VirtualBox build/clean/export scripts, wrapped for NixOS";
      homepage = "https://github.com/mandiant/flare-vm";
      license = lib.licenses.asl20;
      platforms = lib.platforms.linux;
      mainProgram = "vbox-build-flare-vm";
    };
  })
