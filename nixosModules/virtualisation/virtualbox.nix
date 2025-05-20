{ config, lib, ...}:
let
  cfg = config.virtualisation.host.virtualbox;
in{
  options.virtualisation.host.virtualbox = lib.mkEnableOption "Enable virtualbox host";

  config = lib.mkIf cfg {
    virtualisation.virtualbox.host = {
      enable = true;
      enableExtensionPack = true;
      addNetworkInterface = true;
    };
    
    # Add user to vboxusers
    users.extraGroups.vboxusers.members = [
      config.username
    ];

    # Block kvm kernel module since this interferes with VBox kernel module
    boot.blacklistedKernelModules = [
      "kvm-intel"
    ];

  };
}
