{lib, ...}: {
  options.desktopEnvironment.displayManager = {
    enable = lib.mkEnableOption "Use a custom Display Manager.";
    name = lib.mkOption {
      type = lib.types.enum ["gdm" "sddm" "tuigreet"];
      default = "gdm";
      description = "Select display manager.";
    };
  };
}
