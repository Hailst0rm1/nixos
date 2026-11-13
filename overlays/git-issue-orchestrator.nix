final: prev: {
  git-issue-orchestrator = prev.callPackage ../pkgs/git-issue-orchestrator/package.nix {
    src = final.flake-inputs.git-issue-orchestrator;
  };
}
