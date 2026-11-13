{
  lib,
  rustPlatform,
  makeWrapper,
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
    pname = "git-issue-orchestrator";
    version = "0.1.0";
    inherit src;
    cargoLock.lockFile = "${src}/Cargo.lock";

    # The agent box assumes FHS paths; on NixOS it must see /nix/store and the profiles.
    patches = [../../patches/git-issue-orchestrator/0001-agent-box-nixos-store-and-profiles.patch];

    nativeBuildInputs = [makeWrapper];

    # Many tests need bwrap, git remotes or a display; none run in the build sandbox.
    doCheck = false;

    # The desktop app starts orchestrator-engine from its own folder, so all land in $out/bin.
    # The app reads its fonts at runtime, from ORCH_FONT_DIR or `fonts/` beside itself.
    postInstall = ''
      install -Dm644 -t $out/share/git-issue-orchestrator/fonts apps/desktop/assets/fonts/*.ttf
    '';

    postFixup = ''
      wrapProgram $out/bin/orchestrator-desktop \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
        --set ORCH_FONT_DIR $out/share/git-issue-orchestrator/fonts
    '';

    meta = {
      description = "Runs coding agents on GitHub issues, each in a bubblewrap box";
      mainProgram = "orchestrator-desktop";
      platforms = lib.platforms.linux;
    };
  }
