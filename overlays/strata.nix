final: prev: {
  strata = prev.callPackage ../pkgs/strata/package.nix {
    rustPlatform = final.flake-inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.rustPlatform;
  };
}
