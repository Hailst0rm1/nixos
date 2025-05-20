{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [inputs.sops-nix.nixosModules.sops];

  options.security.sops.enable = lib.mkEnableOption "Enable sops-nix";

  config = lib.mkIf config.security.sops.enable {
    environment.systemPackages = with pkgs; [
      sops
      age
    ];

    # Secrets
    sops = {
      validateSopsFiles = false;

      defaultSopsFile = "${config.nixosDir}/secrets/secrets.yaml";
      defaultSopsFormat = "yaml";
      age.keyFile = "/home/${config.username}/.config/sops/age/keys.txt";

      # secrets."${config.username}-password".neededForUsers = true; # User password
    };
  };
}
