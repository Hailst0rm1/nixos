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
        # Automatically import host SSH-keys as Age-keys
        sshKeyPaths = lib.mkIf config.services.openssh.enable ["/etc/ssh/ssh_host_ed25519_key"];
        keyFile = "/var/lib/sops-nix/key.txt";
        generateKey = true;
      };

      secrets."passwords/${config.username}".neededForUsers = true; # User password
      secrets."keys/yubikey/${config.hostname}" = {};
    };
  };
}
