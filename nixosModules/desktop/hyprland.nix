{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.desktopEnvironment.name;
in {
  config = lib.mkIf (cfg == "hyprland") {
    nix.settings = {
      substituters = ["https://hyprland.cachix.org"];
      trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
    };

    services.displayManager.autoLogin = {
      enable = true;
      user = "${config.username}";
    };

    programs.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.system}.hyprland;
      portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
    };

    environment.sessionVariables = {
      GDK_BACKEND = "wayland,x11";
      NIXOS_OZONE_WL = "1";
    };

    programs.gnome-disks.enable = true; # Gnome disks program
    programs.dconf.enable = true;
    #programs.xfconf.enable = true;

    # Automount
    services.devmon.enable = true;
    services.udisks2 = {
      enable = true;
      mountOnMedia = true;
    };

    services.tumbler.enable = true; # Thumbnail generation for file-managers
    services.gnome.gnome-keyring.enable = true;

    # Hyprpanel dependencies
    services.gvfs.enable = true;
    services.power-profiles-daemon.enable = true;
    services.upower.enable = true;

    security.pam.services.login.enableGnomeKeyring = true;

    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      config = {
        common.default = ["gtk"];
        hyprland.default = [
          "gtk"
          "hyprland"
        ];
      };
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
      ];
    };

    environment.systemPackages = with pkgs; [
      kitty
      gnome-icon-theme
      qt6.qtwayland
      libsForQt5.qt5.qtwayland
      lxqt.lxqt-policykit
      xdg-utils
    ];
  };
}
