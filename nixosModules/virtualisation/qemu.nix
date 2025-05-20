{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.virtualisation.host.qemu;
in {
  options.virtualisation.host.qemu = lib.mkEnableOption "Enable qemu on machine.";

  config = lib.mkIf cfg {
    virtualisation = {
      libvirtd = {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          # Support for emulated TPM, required for Windows 11
          swtpm.enable = true;

          # PCIe passthrough support using OVMF
          ovmf.enable = true;
          # secureBoot required for Windows 11
          ovmf.packages = [pkgs.OVMFFull.fd];
        };
      };
    };

    boot.kernelParams = ["intel_iommu=on" "iommu=pt"];

    users.users.${config.username}.extraGroups = ["libvirtd"];

    home-manager.users.${config.username} = {
      dconf.settings = {
        "org/virt-manager/virt-manager/connections" = {
          autoconnect = ["qemu:///system"];
          uris = ["qemu:///system"];
        };
      };
    };

    environment.systemPackages = with pkgs; [
      spice
      spice-gtk
      spice-protocol
      virt-manager
      virt-viewer
      virtio-win
      win-spice
    ];

    services.spice-vdagentd.enable = true;
  };
}

