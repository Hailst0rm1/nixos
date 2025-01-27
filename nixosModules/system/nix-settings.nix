{...}: {
  # Enable flakes
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true; # Store cleanup
  };

  # Automatic cleanup
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 10d";
  };

  # Automatic system upgrades (weekly)
  system.autoUpgrade = {
    enable = true;
    operation = "boot";
    flake = "$HOME/.nixos";
    flags = [ "--update-input" "nixpkgs" "--commit-lock-file" ];
    dates = "weekly";
  };
}

