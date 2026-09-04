final: prev: {
  free-claude-code = final.callPackage ../pkgs/free-claude-code/package.nix {
    inherit (final.flake-inputs) uv2nix pyproject-nix pyproject-build-systems;
  };
}
