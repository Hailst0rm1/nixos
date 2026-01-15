{
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: {
  home.packages = [
    pkgs.vagrant
  ];
}
