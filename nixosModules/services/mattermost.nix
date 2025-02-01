{ config, lib, pkgs, ... }:
let
  cfg = config.services.mattermost;
in {
  config.services.mattermost = lib.mkIf cfg.enable {
    package = pkgs.mattersmost;
    siteUrl = "https://localhost:8065";
  };
}
