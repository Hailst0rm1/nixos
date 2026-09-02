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
      # Use stable Hyprland from nixpkgs instead of git main
      # package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      # portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    };

    environment.sessionVariables = {
      GDK_BACKEND = "wayland,x11";
      NIXOS_OZONE_WL = "1";
    };

    # serpantinum's screen recorder shells out to gpu-screen-recorder, whose
    # KMS capture path needs a root helper for /dev/dri/card*. Without this the
    # helper is launched through pkexec, so every recording opens a password
    # prompt and writes no file if the prompt is dismissed. This option grants
    # gsr-kms-server cap_sys_admin through a setcap wrapper instead. The
    # recorder already prepends /run/wrappers/bin to its own PATH, so the
    # bundled copy inside serpantinum picks the wrapper up too.
    programs.gpu-screen-recorder.enable = true;

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
    # services.gnome.gnome-keyring.enable = true;

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
      # kitty
      gnome-icon-theme
      qt6.qtwayland
      libsForQt5.qt5.qtwayland
      lxqt.lxqt-policykit
      xdg-utils
    ];
  };
}
