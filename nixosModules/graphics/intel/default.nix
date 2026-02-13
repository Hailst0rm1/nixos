{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.graphicDriver.intel;
in {
  options.graphicDriver.intel = {
    enable = lib.mkEnableOption "Download gpu drivers for intel";
    forceProbe = lib.mkOption {
      default = "";
      type = lib.types.str;
      description = "Device ID for i915.force_probe kernel parameter (e.g. 'a7a0'). Leave empty to skip.";
    };
  };

  # WARNING:
  # - Some settings may need to be tuned for older chips:
  # - https://nixos.wiki/wiki/Intel_Graphics

  config = lib.mkIf cfg.enable {
    # Insert device ID for GPU found with:
    # nix-shell --extra-experimental-features "flakes" -p pciutils --run "lspci -nn | grep VGA"
    boot.kernelParams = lib.optionals (cfg.forceProbe != "") [
      "i915.force_probe=${cfg.forceProbe}"
    ];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-compute-runtime
        vpl-gpu-rt
        intel-ocl
      ];
    };

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };
  };
}
