{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  options.security.sops.enable = lib.mkEnableOption "Enable sops-nix";

  imports = [inputs.sops-nix.nixosModules.sops];

  config = lib.mkMerge [
    # When sops is disabled, prevent validation of secrets
    (lib.mkIf (!config.security.sops.enable) {
      sops.validateSopsFiles = false;
    })

    # When sops is enabled, configure secrets
    (lib.mkIf config.security.sops.enable {
      environment.systemPackages = with pkgs; [
        sops
        age
      ];

      # Secrets
      sops = {
        validateSopsFiles = true;

        defaultSopsFile = ../../secrets/${config.username}.yaml;
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
        secrets."services/hermes-agent/env" = lib.mkIf config.services.hermes-agent.enable {
          owner = "hailst0rm";
          mode = "0400";
          # Restart the consumers when the env blob changes (e.g. a new
          # HERMES_DASHBOARD_SESSION_TOKEN) — the unit text is unchanged on a
          # rebuild, so without this the dashboard keeps its old token and the
          # desktop's WS auth fails.
          restartUnits =
            ["hermes-agent.service"]
            ++ lib.optional config.services.hermes-agent.dashboard.enable "hermes-dashboard.service";
        };
        # Raw session token for the desktop client's HERMES_DESKTOP_REMOTE_TOKEN;
        # must equal the server's HERMES_DASHBOARD_SESSION_TOKEN. Decrypted only
        # on hosts that point the desktop at a remote backend.
        secrets."services/hermes-agent/desktop-token" = lib.mkIf (config.services.hermes-agent.desktop.enable && config.services.hermes-agent.desktop.remoteUrl != "") {
          owner = "hailst0rm";
          mode = "0400";
        };
        secrets."services/signal-cli/account" = lib.mkIf config.services.hermes-agent.signal.enable {
          owner = "hailst0rm";
          mode = "0400";
        };
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
    })
  ];
}
