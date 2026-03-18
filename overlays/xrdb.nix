# Workaround: pkgs.xrdb was removed as a top-level alias in nixpkgs.
# Home Manager's xresources.nix still references it unconditionally.
# Re-alias until the upstream fix lands.
final: prev: {
  xrdb = prev.xorg.xrdb;
}
