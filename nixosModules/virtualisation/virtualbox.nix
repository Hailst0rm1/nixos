{
  config,
  lib,
  ...
}: let
  cfg = config.virtualisation.host.virtualbox;
in {
  options.virtualisation.host.virtualbox = lib.mkEnableOption "Enable virtualbox host";

  config = lib.mkIf cfg {
    virtualisation.virtualbox.host = {
      enable = true;
      enableExtensionPack = true;
      addNetworkInterface = true;
    };

    # Create the interface before assigning addresses during activation.
    systemd.services.network-addresses-vboxnet0 = lib.mkIf (!config.networking.useNetworkd) {
      requires = ["vboxnet0.service"];
      after = ["vboxnet0.service"];
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
