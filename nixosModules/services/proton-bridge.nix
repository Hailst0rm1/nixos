{
  config,
  lib,
  ...
}: let
  cfg = config.services.proton-bridge;
in {
  options.services.proton-bridge.enable = lib.mkEnableOption "Proton Mail Bridge";
  config = lib.mkIf cfg.enable {
    services.protonmail-bridge.enable = true;
  };
}
