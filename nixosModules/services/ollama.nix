{ config, lib, pkgs-unstable, ... }:
let
  cfg = config.services.ollama;
in {
  config.services.ollama = lib.mkIf cfg.enable {
    package = pkgs-unstable.ollama;
    acceleration = "cuda";
  };
}
