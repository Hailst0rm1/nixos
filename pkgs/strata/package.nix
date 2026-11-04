{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  wrapGAppsHook4,
  gtk4,
  gtksourceview5,
  poppler,
  fontconfig,
  gst_all_1,
  bubblewrap,
  util-linux,
  ffmpeg,
  ffmpegthumbnailer,
  imagemagick,
  squashfsTools,
}: let
  helpers = [util-linux ffmpeg ffmpegthumbnailer imagemagick squashfsTools];
in
  rustPlatform.buildRustPackage rec {
    pname = "strata";
    version = "1.1.0";

    src = fetchFromGitHub {
      owner = "lgse";
      repo = "strata";
      rev = "v${version}";
      hash = "sha256-FoYYsjvWY+1SuZtvxancdVR6h7iFmnbtHXW2eTlVCJI=";
    };
    cargoHash = "sha256-U52ypUksrz/2G8apmyh7x9c+47ZBStT1lHIWso7KfU4=";
    buildNoDefaultFeatures = true;
    # shortcut: upstream integration tests fail in the Nix builder; enable once they pass there.
    doCheck = false;

    nativeBuildInputs = [pkg-config wrapGAppsHook4];
    buildInputs = [gtk4 gtksourceview5 poppler fontconfig] ++ (with gst_all_1; [gstreamer gst-plugins-base gst-plugins-good gst-libav]);

    # Keep upstream's isolated preview helpers working with Nix store paths.
    STRATA_SANDBOX_ROOT = "/nix/store";
    STRATA_SANDBOX_PATH = lib.makeBinPath helpers;
    STRATA_SANDBOX_PRLIMIT = "${util-linux}/bin/prlimit";

    patches = [../../patches/strata/0001-find-bwrap-on-nixos.patch];
    postPatch = ''
      substituteInPlace src/trusted_command.rs --replace-fail @bubblewrap@ ${bubblewrap}
    '';

    postInstall = ''
      install -Dm644 data/io.github.lgse.Strata.desktop $out/share/applications/io.github.lgse.Strata.desktop
      install -Dm644 data/io.github.lgse.Strata.FileManager1.service $out/share/dbus-1/services/org.freedesktop.FileManager1.service
      substituteInPlace $out/share/dbus-1/services/org.freedesktop.FileManager1.service \
        --replace-fail /usr/bin/strata $out/bin/strata
      install -Dm644 data/portal/strata.portal $out/share/xdg-desktop-portal/portals/strata.portal
      install -Dm644 data/portal/org.freedesktop.impl.portal.desktop.strata.service.in \
        $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service
      substituteInPlace $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service \
        --replace-fail @STRATA_EXECUTABLE@ $out/bin/strata
      # The coloured README logo; the bundled app icon is plain white.
      install -Dm644 docs/assets/logos/strata-tokyo-night.svg $out/share/icons/hicolor/scalable/apps/io.github.lgse.Strata.svg
    '';

    meta = {
      description = "A fast, keyboard-first file manager for Linux";
      homepage = "https://github.com/lgse/strata";
      license = lib.licenses.mit;
      mainProgram = "strata";
      platforms = lib.platforms.linux;
    };
  }
