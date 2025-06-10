{pkgs ? import <nixpkgs> {}}:
pkgs.mkShell {
  nativeBuildInputs = [
    pkgs.pkgsCross.mingwW64.buildPackages.gcc
  ];
}
