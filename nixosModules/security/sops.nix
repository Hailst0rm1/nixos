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
      secrets."services/cloudflared/creds" = lib.mkIf config.services.cloudflared.enable {};
      secrets."services/tailscale/auth.key" = lib.mkIf config.services.tailscaleAutoconnect.enable {};
      secrets."services/ghost/pontonsecurity/cert.pem" = lib.mkIf config.services.ghost.enable {
        group = "nginx";
        mode = "0440";
      };
      secrets."services/ghost/pontonsecurity/cert.key" = lib.mkIf config.services.ghost.enable {
        group = "nginx";
        mode = "0440";
      };

      secrets."services/gitlab/db-password" = lib.mkIf config.services.gitlab.enable {
        group = "git";
        mode = "0440";
      };
      secrets."services/gitlab/root-password" = lib.mkIf config.services.gitlab.enable {
        group = "git";
        mode = "0440";
      };
      secrets."services/gitlab/secret" = lib.mkIf config.services.gitlab.enable {
        group = "git";
        mode = "0440";
      };
      secrets."services/gitlab/otp" = lib.mkIf config.services.gitlab.enable {
        group = "git";
        mode = "0440";
      };
      secrets."services/gitlab/db" = lib.mkIf config.services.gitlab.enable {
        group = "git";
        mode = "0440";
      };
      secrets."services/gitlab/jws" = lib.mkIf config.services.gitlab.enable {
        group = "git";
        mode = "0440";
      };
      secrets."services/gitlab/recordPrimary" = lib.mkIf config.services.gitlab.enable {
        group = "git";
        mode = "0440";
      };
      secrets."services/gitlab/recordDeterministic" = lib.mkIf config.services.gitlab.enable {
        group = "git";
        mode = "0440";
      };
      secrets."services/gitlab/recordSalt" = lib.mkIf config.services.gitlab.enable {
        group = "git";
        mode = "0440";
      };
    };
  };
}
