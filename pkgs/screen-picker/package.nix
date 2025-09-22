{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  glib,
  gobject-introspection,
  gtk4,
  gtk4-layer-shell,
  hyprland,
  xdg-desktop-portal-hyprland,
}:
rustPlatform.buildRustPackage rec {
  pname = "hyprland-preview-share-picker";
  version = "unstable-2025-09-21"; # you can pin a commit or tag if you prefer

  src = fetchFromGitHub {
    owner = "WhySoBad";
    repo = "hyprland-preview-share-picker";
    rev = "211b7890ed3332f4d1bb1f1a96999e18874a9c3c"; # update to latest commit you want
    hash = "sha256-Zztb0soSN/NynWnBIGPuUNRKt2xSx/+f+QpYIPRyRdc="; # fill in with nix-prefetch
    fetchSubmodules = true;
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
  };

  nativeBuildInputs = [
    pkg-config
    gobject-introspection
  ];

  buildInputs = [
    glib
    gtk4
    gtk4-layer-shell
    hyprland
    xdg-desktop-portal-hyprland
  ];

  meta = with lib; {
    description = "A GTK4-based preview share picker for Hyprland";
    homepage = "https://github.com/WhySoBad/hyprland-preview-share-picker";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [];
    platforms = platforms.linux;
  };
}
