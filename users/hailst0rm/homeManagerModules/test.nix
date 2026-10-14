{
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: {
  home.packages = [
    # pkgs.vagrant
    pkgs.kitty
    pkgs.mysql84
    pkgs.mycli
  ];
}
