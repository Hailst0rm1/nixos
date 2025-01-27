{
  config,
  lib,
  pkgs-unstable,
  ...
}: {
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
}

