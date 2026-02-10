{
  pkgs,
  pkgs-unstable,
  lib,
  config,
  ...
}: {
  # environment.systemPackages = with pkgs; [(pkgs.callPackage "${self}/pkgs/companion/package.nix" {})];
  environment.systemPackages = [
  ];
}
