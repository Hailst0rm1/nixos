{pkgs ? import <nixpkgs> {}, ...}: {
  default = pkgs.mkShell {
    nativeBuildInputs = [
      pkgs.pkgsCross.mingwW64.buildPackages.gcc
    ];
  };
}
