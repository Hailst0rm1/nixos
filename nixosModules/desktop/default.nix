{ lib, ... }: {
  options.desktopEnvironment.name = lib.mkOption {
    type = lib.types.str;
    default = "gnome";
    description = "Select the desktop environment to be installed and configured.";
  };
}
