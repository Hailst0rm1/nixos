{
  pkgs,
  pkgs-unstable,
  ...
}: {
  home.packages = [
    pkgs.kitty
  ];
}
