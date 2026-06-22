final: prev: {
  hermes-agent = prev.callPackage ../pkgs/hermes-agent/package.nix {
    # uv2nix stack comes from the flake inputs injected via generators.nix.
    inherit (final.flake-inputs) uv2nix pyproject-nix pyproject-build-systems;
  };
}
