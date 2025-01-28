{ lib, ... }:
{
  options.desktopEnvironment.displayManager = lib.mkOption {
    type = lib.types.str;
    description = "Select display manager.";
  };
}
