{lib, ...}: {
  options.desktopEnvironment.name = lib.mkOption {
    type = lib.types.enum ["gnome" "xfce" "hyprland" "cosmic" "headless"];
    default = "gnome";
    description = "Select the desktop environment to be installed and configured.";
  };
}
