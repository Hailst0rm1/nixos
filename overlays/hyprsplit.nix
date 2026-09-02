final: prev: {
  # nixpkgs' hyprsplit (v0.54.2, newest available) doesn't compile against
  # nixpkgs' hyprland (0.55.4): Hyprland removed g_pConfigManager/SWorkspaceRule
  # (now Config::workspaceRuleMgr()/Config::CWorkspaceRule) and
  # CWorkspaceHistoryTracker::dataFor() with no replacement. Patched rather than
  # dropped — hyprsplit's per-monitor numbered workspaces are wired through
  # hyprland.nix and the serpantinum WorkspacesWidget patch depends on the
  # numbering scheme. The dataFor()-based previous-workspace swap in
  # split:swapactiveworkspaces has no equivalent in the new history API and is
  # dropped rather than guessed at — see the patch's own comment.
  hyprlandPlugins =
    prev.hyprlandPlugins
    // {
      hyprsplit = prev.hyprlandPlugins.hyprsplit.overrideAttrs (old: {
        patches =
          (old.patches or [])
          ++ [
            ../patches/hyprsplit/0001-hyprland-0.55-workspace-rule-api.patch
          ];
      });
    };
}
