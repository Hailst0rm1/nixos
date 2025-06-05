{pkgs ? import <nixpkgs> {}}:
pkgs.mkShell {
  nativeBuildInputs = [
    pkgs.pkgsCross.mingwW64.buildPackages.gcc
    pkgs.python313Packages.netifaces2
    pkgs.python313Packages.aioquic
    pkgs.python313
  ];
}
