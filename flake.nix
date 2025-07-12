{
  description = "Hailst0rm NixOS Configuration";

  inputs = {
    # ===================== Flakes ===================== #

    # Home Manager manages dot files and user applications
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Cosmic DE Alpha for testing
    nixos-cosmic = {
      url = "github:lilyinstarlight/nixos-cosmic";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };

    # Hyprland
    hyprland.url = "github:hyprwm/Hyprland";
    # hyprpanel = {
    #   # url = "github:Jas-SinghFSU/HyprPanel";
    #   url = "github:Jas-SinghFSU/HyprPanel?rev=94a00a49dae15c87e4234c9962295aed2b0dc45e";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # Generators for building isos and VMs
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixOS official package source
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    # Source so that we can use some packages from unstable as well
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # A collection of NixOS modules covering hardware quirks.
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Stylix is used for theming
    stylix = {
      url = "github:danth/stylix/release-25.05";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    # Declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen Browser
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Spotify theme
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";

    # Discord plugins and theme
    nixcord = {
      url = "github:kaylorben/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # More vscode extensions
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    flake-utils.url = "github:numtide/flake-utils";

    # Secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Neovim
    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {self, ...}: let
    # Generator functions for Machines and VMs
    myLib = import ./lib/generators.nix {inherit inputs;};
    system = "x86_64-linux";
  in
    with myLib; {
      # ===================== DevShells (nix develop) ===================== #

      devShells.${system} = import ./shell.nix {pkgs = inputs.nixpkgs.legacyPackages.${system};};

      # ===================== Physical Machines ===================== #

      nixosConfigurations = {
        # Home Workstation
        Nix-Workstation = mkSystem {hostname = "Nix-Workstation";};

        # Work Laptop
        Nix-Laptop = mkSystem {hostname = "Nix-Laptop";};

        # External SSD
        Nix-ExtDisk = mkSystem {hostname = "Nix-ExtDisk";};

        # Nix-Minimal
        Nix-Minimal = mkSystem {hostname = "Nix-Minimal";};

        # Nix-Installer
        Nix-Installer = mkSystem {hostname = "Nix-Installer";};
      };

      # ===================== VM:s + ISO ===================== #

      packages.x86_64-linux = {
        # Experimental VM for redteaming
        # h4kn1x = mkImage {
        #   inherit system nixos-dir username;
        #   hostname = "h4kn1x";
        #   desktop = "xfce+i3";
        #   format = "vmware";
        #   diskSize = builtins.toString (50 * 1024);
        # };

        # # .iso for Yubikey and GPG key setup on air gapped host.
        # crypt0n1x = mkImage {
        #   inherit system nixos-dir username;
        #   hostname = "crypt0n1x";
        #   desktop = "none+i3";
        #   format = "iso";
        #   diskSize = "auto";
        # };

        # # Custom installer
        # st4ll1x = mkImage {
        #   inherit system nixos-dir username;
        #   hostname = "st4ll1x";
        #   desktop = "none+i3";
        #   format = "iso";
        #   diskSize = "auto";
        # };
        # # Custom installer
        # k1t = mkImage {
        #   inherit system nixos-dir username;
        #   hostname = "k1t";
        #   desktop = "none";
        #   format = "vmware";
        #   diskSize = builtins.toString (50 * 1024);
        # };
      };
    };
}
