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

  # Parallel Volatility 3 runner (vol-wrapper) + plugin inventory generator.
  # From unstable so it drives the same volatility3 installed below.
  vol-wrapper = pkgs-unstable.callPackage "${nixosDir}/pkgs/vol-wrapper/package.nix" {};

  # Host-side lab helper: creates the isolated `malware-net` internal network
  # and applies per-VM NIC/clipboard/USB isolation via VBoxManage.
  dfir-vm-network = pkgs.writeShellScriptBin "dfir-vm-network" (builtins.readFile ./files/dfir/host/vm-network.sh);

  # Builds the clean Windows BUILD-READY base VM from an ISO, unattended.
  # Needs xorriso (to pack autounattend.xml) + ambient VBoxManage.
  dfir-create-base = pkgs.writeShellApplication {
    name = "dfir-create-base";
    runtimeInputs = [pkgs.xorriso pkgs.gnugrep]; # gnugrep: the answer file's ASCII guard needs grep -P
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
    # Colemak-SE's Windows installer, staged into both VMs by
    # dfir-prepare-variant (see files/dfir/windows/set-colemak-se.ps1).
    home.file.".config/dfir/windows/se-cmak_amd64.msi".source = let
      colemakSeRelease = "1.0";
    in
      pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/motform/colemak-se/refs/tags/${colemakSeRelease}/release/windows/se-cmak_amd64.msi";
        hash = "sha256-ZDPJDMrpRIApnaJvSssilSDq1RB6P1EoFaPxa3qEAFw=";
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

        # === FLARE-VM recommended set, Linux-native (kept off the malware VM,
        # see files/dfir/config/malware-config.xml; the triage utilities there
        # are on both). 7zip and file come from nixosModules/system/utils.nix. ===
        _010editor
        # angr-management omitted: nixpkgs python3Packages.angr 9.2.193 fails
        # to build (missing setuptools-rust), and angr-management is pinned to 9.2.154.
        # Installed on the malware VM instead (files/dfir/config/malware-config.xml).
        apktool
        asar
        avalonia-ilspy # ILSpy's cross-platform frontend
        bytecode-viewer
        dex2jar
        goresym
        innoextract
        js-beautify
        keystone # kstool
        magika
        nasm
        nmap
        pe-bear
        pycdc # pycdc + pycdas
        upx
        python3Packages.autoit-ripper
        python3Packages.uncompyle6

        # === Filesystem / disk image forensics ===
        autopsy
        # sleuthkit
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
        vol-wrapper
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
