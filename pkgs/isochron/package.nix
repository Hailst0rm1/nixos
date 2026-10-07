{
  lib,
  rustPlatform,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  wayland,
  libxkbcommon,
  libGL,
  vulkan-loader,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  # Private repo, fetched as a flake input (git+ssh) — see flake.nix.
  src,
}: let
  # eframe dlopens its windowing/graphics libs at runtime.
  runtimeLibs = [wayland libxkbcommon libGL vulkan-loader libx11 libxcursor libxi libxrandr];
in
  rustPlatform.buildRustPackage {
    pname = "isochron";
    version = "0.1.0";
    inherit src;
    cargoLock.lockFile = "${src}/Cargo.lock";

    nativeBuildInputs = [makeWrapper copyDesktopItems];

    # Launcher entry; the icon is the app's own D mark (256px, from the repo).
    desktopItems = [
      (makeDesktopItem {
        name = "isochron";
        desktopName = "Isochron";
        comment = "DFIR log timeline viewer";
        exec = "isochron %F";
        # Absolute path: the launcher's themed lookup missed the hicolor copy.
        icon = "${src}/assets/d_logo.png";
        categories = ["Utility" "Security"];
        startupWMClass = "Isochron"; # eframe uses run_native's app name as app_id
      })
    ];

    postInstall = ''
      install -Dm644 ${src}/assets/d_logo.png \
        $out/share/icons/hicolor/256x256/apps/isochron.png
    '';

    postFixup = ''
      wrapProgram $out/bin/isochron \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
    '';

    meta = {
      description = "DFIR log timeline viewer";
      mainProgram = "isochron";
      platforms = lib.platforms.linux;
    };
  }
