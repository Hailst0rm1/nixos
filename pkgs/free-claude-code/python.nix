{
  lib,
  python314,
  callPackage,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
  src,
}: let
  workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = src;};

  pythonSet = (callPackage pyproject-nix.build.packages {python = python314;})
    .overrideScope (lib.composeManyExtensions [
    pyproject-build-systems.overlays.default
    (workspace.mkPyprojectOverlay {sourcePreference = "wheel";})
  ]);
in
  pythonSet.mkVirtualEnv "free-claude-code-env" {
    free-claude-code = [];
  }
