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

    # Upstream module wires the user unit to graphical-session.target, which
    # never activates on a headless host. Re-target it at default.target so
    # the per-user manager (lingering) starts it at boot.
    systemd.user.services.protonmail-bridge = {
      wantedBy = lib.mkForce ["default.target"];
      after = lib.mkForce ["network-online.target"];
      wants = ["network-online.target"];
    };
  };
}
