{
  inputs,
  config,
  lib,
  ...
}: {
  imports = [inputs.sops-nix.homeManagerModules.sops];

  options.importConfig.sops.enable = lib.mkEnableOption "Enable User-level sops-nix.";

  config = lib.mkMerge [
    # When sops is disabled, prevent validation of secrets
    (lib.mkIf (!config.importConfig.sops.enable) {
      sops.validateSopsFiles = false;
    })

    (lib.mkIf config.importConfig.sops.enable {
      sops = {
        age.keyFile = "/home/${config.username}/.config/sops/age/keys.txt";
        age.sshKeyPaths = []; # Only use the user age key, not host SSH keys

        defaultSopsFile = ../../../secrets/${config.username}.yaml;
        validateSopsFiles = true;

        secrets = {
          "keys/ssh/${config.username}" = {
            path = "/home/${config.username}/.ssh/id_${config.username}";
          };
          "keys/ssh/github" = {
            path = "/home/${config.username}/.ssh/github";
          };
          "keys/ssh/yubia" = {
            path = "/home/${config.username}/.ssh/yubia";
          };
          "keys/ssh/yubic" = {
            path = "/home/${config.username}/.ssh/yubic";
          };
          "keys/yubikey/${config.hostname}" = {
            path = "/home/${config.username}/.config/Yubico/u2f_keys";
          };
          "vpn/aws-leech" = {
            path = "/home/${config.username}/.vpn/aws-leech.ovpn";
          };
          "vpn/htb" = {
            path = "/home/${config.username}/.vpn/htb.ovpn";
          };
          "vpn/offsec" = {
            path = "/home/${config.username}/.vpn/offsec.ovpn";
          };
          "services/openweather" = {};
          "services/perplexity/api-key" = {};
          "services/exa/api-key" = {};
          "services/n8n/api-key" = {};
          "services/context7/api-key" = {};
          "services/github/pat" = {};
          # Sandcastle autonomous agent pipeline (see code/sandcastle.nix):
          #   - claude-oauth-token: output of `claude setup-token` (subscription
          #     headless auth → CLAUDE_CODE_OAUTH_TOKEN).
          #   - sandcastle-pat: a FINE-GRAINED GitHub PAT scoped to ONLY the
          #     target repos (issues:rw, contents:rw, pull-requests:rw) — keeps
          #     the blast radius off your account-wide pat.
          "services/anthropic/claude-oauth-token" = {};
          "services/github/sandcastle-pat" = {};
          "services/kie/api-key" = {};
          "services/obsidian/e2ee-password" = {};
        };
      };
    })
  ];
}
