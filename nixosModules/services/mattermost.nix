{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.mattermost;
in {
  config.services.mattermost = lib.mkIf cfg.enable {
    package = pkgs.mattermost;
    host = "0.0.0.0";
    port = 8065;
    siteUrl = "https://172.16.11.105:8065";
    database.peerAuth = true;
  };
}
