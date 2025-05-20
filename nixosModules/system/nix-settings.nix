{
  config,
  lib,
  ...
}: let
  cfg = config.system.automatic;
in {
  options.system.automatic = {
    upgrade = lib.mkEnableOption "Enable weekly system upgrades";
    cleanup = lib.mkEnableOption "Enable automatic system cleanup every 30 days";
  };

  config = {
    # Enable flakes
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true; # Store cleanup
    };

    # Automatic cleanup
    nix.gc = lib.mkIf cfg.upgrade {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 30d";
    };

    # Automatic system upgrades (weekly)
    system.autoUpgrade = lib.mkIf cfg.upgrade {
      enable = true;
      operation = "boot";
      flake = "${config.nixosDir}";
      flags = ["--update-input" "nixpkgs" "--commit-lock-file"];
      dates = "weekly";
    };
  };
}
