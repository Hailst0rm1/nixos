{
  inputs,
  pkgs-unstable,
  lib,
  config,
  ...
}: let
  cfg = config.importConfig.stylix;
in {
  options.importConfig.stylix = {
    enable = lib.mkEnableOption "Enable user stylix config.";
  };

  config = lib.mkIf cfg.enable {
    stylix = {
      enable = true;
      enableReleaseChecks = false;
      autoEnable = cfg.enable;
      opacity = lib.mkIf cfg.enable {
        applications = lib.mkForce 0.5;
        desktop = lib.mkForce 0.5;
        popups = lib.mkForce 0.5;
        terminal = lib.mkForce 0.5;
      };

      targets = lib.mkIf cfg.enable {
        ghostty.enable = true;
        helix.enable = false;
        neovim.enable = false;
        # yazi.enable = false;
        #nixcord.enable = true; On next release or when backported
      };
    };

    # xdg.desktopEntries.vmware-workstation = lib.mkIf cfg.enable {
    #   name = "VMware Workstation";
    #   comment = "Run and manage virtual machines";
    #   exec = "env GTK_THEME=Adwaita:dark ${pkgs-unstable.vmware-workstation}/bin/vmware %U";
    #   terminal = false;
    #   type = "Application";
    #   icon = "vmware-workstation";
    #   startupNotify = true;
    #   categories = ["System"];
    #   mimeType = [
    #     "application/x-vmware-vm"
    #     "application/x-vmware-team"
    #     "application/x-vmware-enc-vm"
    #     "x-scheme-handler/vmrc"
    #   ];
    # };
  };
}
