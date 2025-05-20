{ config, lib, pkgs, ... }:
let
  cfg = config.services.mattermost;
in {
  config.services.mattermost = lib.mkIf cfg.enable {
    package = pkgs.mattermost;
    siteUrl = "https://localhost:8065";
  };
}
