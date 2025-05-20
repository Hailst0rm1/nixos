{
  config,
  lib,
  pkgs-unstable,
  ...
}: let
  cfg = config.graphicDriver.intel;
in {
  options.graphicDriver.intel = {
    enable = lib.mkEnableOption "Download gpu drivers for intel";
  };

  config = lib.mkIf cfg.enable {
    # Insert device ID for GPU found with:
    # nix-shell --extra-experimental-features "flakes" -p pciutils --run "lspci -nn | grep VGA"
    boot.kernelParams = ["i915.force_probe=7d55"];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs-unstable; [
        intel-media-driver
        intel-vaapi-driver
        libvdpau-va-gl
        intel-ocl
      ];
    };

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };
  };
}
