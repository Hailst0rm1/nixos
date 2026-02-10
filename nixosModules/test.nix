{
  pkgs,
  pkgs-unstable,
  lib,
  config,
  ...
}: {
  environment.systemPackages = with pkgs; [
    companion
  ];
}
