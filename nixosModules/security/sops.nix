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
      validateSopsFiles = true;

      defaultSopsFile = ../../secrets/secrets.yaml;
      defaultSopsFormat = "yaml";
      age = {
        sshKeyPaths = ["/home/${config.username}/.ssh/sops"];
        keyFile = "/home/${config.username}/.config/sops/age/keys.txt";
        generateKey = true;
      };

      secrets."${config.username}/user_password".neededForUsers = true; # User password (doesn't work?)
    };
  };
}
