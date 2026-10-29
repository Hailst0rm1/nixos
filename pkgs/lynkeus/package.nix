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
    pname = "lynkeus";
    version = "0.1.0";
    inherit src;
    cargoLock.lockFile = "${src}/Cargo.lock";

    # lynkeus-app is not a default workspace member; name all three binaries' crates.
    # shortcut: --ignore-rust-version because Cargo.toml asks 1.99 and nixpkgs-unstable has 1.97
    # (it compiles fine); drop it once pkgs-unstable.rustc >= 1.99.
    # The app finds lynkeus-worker next to its own executable, so all land in $out/bin.
    cargoBuildFlags = ["--ignore-rust-version" "-p" "lynkeus-cli" "-p" "lynkeus-worker" "-p" "lynkeus-app"];

    nativeBuildInputs = [makeWrapper copyDesktopItems];

    # Test suite runs on generated captures and is slow; CI upstream covers it.
    doCheck = false;

    desktopItems = [
      (makeDesktopItem {
        name = "lynkeus";
        desktopName = "Lynkeus";
        comment = "Network capture analysis";
        exec = "lynkeus-app %F";
        # Absolute path: the launcher's themed lookup missed the hicolor copy.
        icon = "${src}/crates/lynkeus-app/assets/d_logo.png";
        categories = ["Utility" "Security"];
        startupWMClass = "lynkeus"; # main.rs sets with_app_id("lynkeus")
      })
    ];

    postInstall = ''
      install -Dm644 ${src}/crates/lynkeus-app/assets/d_logo.png \
        $out/share/icons/hicolor/256x256/apps/lynkeus.png
    '';

    postFixup = ''
      wrapProgram $out/bin/lynkeus-app \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
    '';

    meta = {
      description = "Network capture analysis (pcap) with sandboxed workers";
      mainProgram = "lynkeus";
      platforms = lib.platforms.linux;
    };
  }
