{
  config,
  lib,
  ...
}: let
  cfg = config.system.automatic;
in {
  options.system.automatic = {
    upgrade = lib.mkEnableOption "Enable weekly system upgrades";
    cleanup = lib.mkEnableOption "Enable weekly nix store garbage collection (keeps 30 days)";
  };

  config = {
    # Enable flakes
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true; # Store cleanup

      # Binary caches (this module owns all nix.settings)
      substituters = ["https://devenv.cachix.org"];
      trusted-public-keys = ["devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="];
    };

    # Automatic store garbage collection (gated on its own option)
    nix.gc = lib.mkIf cfg.cleanup {
      automatic = true;
      dates = "weekly";
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
