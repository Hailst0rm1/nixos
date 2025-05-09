{
  pkgs,
  pkgs-unstable,
  ...
}: {
  home.packages = [
    pkgs.ida-free
    pkgs.ghidra
    pkgs.binaryninja-free
  ];
}

