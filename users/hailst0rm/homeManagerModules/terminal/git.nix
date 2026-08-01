{
  config,
  lib,
  ...
}: let
  cfg = config.importConfig.git;

  # Author identity for the second GitHub account. Deliberately does NOT set
  # core.sshCommand: that is repo-wide, and `hasconfig` fires when ANY remote
  # matches, so a repo with a personal `origin` plus a Dfirmed remote would send
  # both through the wrong key. The key comes from the github-dfirmed ssh host
  # alias instead (terminal/ssh.nix), which resolves per-remote.
  dfirmedIdentity = {
    user = {
      name = "K-Dfirmed";
      email = "dfirmed@proton.me";
    };
  };

  # Both the plain and the alias URL form, so identity is picked up whether the
  # remote was cloned normally or already points at the alias.
  dfirmedRemotes = [
    "git@github.com:Dfirmed/**"
    "git@github.com:K-Dfirmed/**"
    "git@github-dfirmed:**"
  ];
in {
  options.importConfig.git.enable = lib.mkEnableOption "Enable Git configuration.";

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "hailst0rm";
          email = "kevin.ponton@pm.me";
        };

        # Route Dfirmed remotes onto the ssh alias at transport time, so a
        # normal `git clone git@github.com:Dfirmed/...` still uses the right
        # key without anyone remembering the alias. Only the matching remote is
        # rewritten; other remotes in the same repo are untouched.
        url."git@github-dfirmed:Dfirmed/".insteadOf = "git@github.com:Dfirmed/";
        url."git@github-dfirmed:K-Dfirmed/".insteadOf = "git@github.com:K-Dfirmed/";
      };

      # Requires git >= 2.36 for the hasconfig condition.
      includes =
        map (url: {
          condition = "hasconfig:remote.*.url:${url}";
          contents = dfirmedIdentity;
        })
        dfirmedRemotes;
    };
  };
}
