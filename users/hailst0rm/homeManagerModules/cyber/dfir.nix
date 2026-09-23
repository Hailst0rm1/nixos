{
  inputs,
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: let
  nixosDir = inputs.self;
  # FLARE-VM VirtualBox build/clean/export scripts, wrapped for NixOS.
  # Provides: vbox-build-flare-vm, vbox-build-remnux, vbox-clean-snapshots,
  # vbox-export-snapshot. They call ambient VBoxManage (guaranteed by the
  # NixOS dfir module enabling the VirtualBox host).
  flare-vbox = pkgs.callPackage "${nixosDir}/pkgs/flare-vbox/package.nix" {};

  # Host-side lab helper: creates the isolated `malware-net` internal network
  # and applies per-VM NIC/clipboard/USB isolation via VBoxManage.
  dfir-vm-network = pkgs.writeShellScriptBin "dfir-vm-network" (builtins.readFile ./files/dfir/host/vm-network.sh);

  # Builds the clean Windows BUILD-READY base VM from an ISO, unattended.
  # Needs xorriso (to pack autounattend.xml) + ambient VBoxManage.
  dfir-create-base = pkgs.writeShellApplication {
    name = "dfir-create-base";
    runtimeInputs = [pkgs.xorriso];
    text = builtins.readFile ./files/dfir/host/create-base-vm.sh;
  };

  # Clones the base VM into each variant's expected VM_NAME + BUILD-READY
  # snapshot, and stages the variant's config.xml/manifest where the FLARE
  # build scripts look for them.
  dfir-prepare-variant = pkgs.writeShellScriptBin "dfir-prepare-variant" (builtins.readFile ./files/dfir/host/prepare-variant.sh);
in {
  # Option declared in nixosModules/variables.nix, which is imported into both
  # the NixOS and HM namespaces (see users/hailst0rm/hosts/default.nix) — like
  # redTools, this module only consumes it, it must not redeclare it.
  config = lib.mkIf config.cyber.dfir.enable {
    # Lab scripts and configs live in the repo under files/dfir; deployed here
    # so the FLARE build scripts and updaters can find them. Recursive = writable
    # dir of per-file symlinks (edit the source in the repo, not the symlink).
    home.file.".config/dfir" = {
      source = ./files/dfir;
      recursive = true;
    };

    home.packages =
      (with pkgs-unstable; [
        # === Reverse engineering / static analysis ===
        ghidra
        binaryninja-free
        rizin
        cutter
        radare2
        detect-it-easy
        capa # flare-capa
        flare-floss
        binwalk
        ssdeep
        yara

        # === Filesystem / disk image forensics ===
        sleuthkit
        libewf
        afflib
        bulk_extractor
        exiftool

        # === Memory forensics ===
        volatility3

        # === Windows artifact parsing (Linux-capable) ===
        chainsaw
        hayabusa-sec
        regripper

        # === Misc ===
        (writeShellScriptBin "cyberchef" ''
          # For encoding/encryption etc
          ${config.browser} "${cyberchef}/share/cyberchef/index.html"
        '')
      ])
      ++ [
        # VM lab tooling (from stable pkgs)
        flare-vbox
        dfir-vm-network
        dfir-create-base
        dfir-prepare-variant
      ];

    # Not yet packaged in nixpkgs (kept on the Windows DFIR VM / a later task):
    #   plaso/log2timeline, timesketch, pe-sieve, Eric Zimmerman tools.
    # EZ Tools' Linux-capable CLI subset runs via dotnetCorePackages.runtime_9_0
    # if host-side coverage is ever wanted.
  };
}
