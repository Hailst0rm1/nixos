{
  config,
  pkgs,
  lib,
  ...
}: {
  options.security.yubikey.enable = lib.mkEnableOption "Enable yubikey";

  config = lib.mkIf config.security.yubikey.enable {
    # Yubikey required services and config
    services = {
      pcscd.enable = true; # Smart Card support needed for Authenticator app
      udev.packages = [pkgs.yubikey-personalization];
      yubikey-agent.enable = true;
      # TODO Lock screen if yubikey is removed
    };

    # Yubikey login / sudo
    security.pam = {
      # MAKE SURE to generate authFile BEFORE enabling this module
      # Generate the file using:
      # `nix-shell -p pam_u2f`
      # `pamu2fcfg > u2f_keys`
      # `sudo mv u2f_keys /etc/Yubico/`
      sshAgentAuth.enable = true;
      u2f = {
        enable = lib.mkDefault true;
        settings = {
          authFile = "/home/${config.username}/.config/Yubico/u2f_keys";
          cue = false; # Tells user they need to press the button if true
        };
      };
      services = {
        login.u2fAuth = lib.mkDefault true;
        sudo = {
          u2fAuth = lib.mkDefault true;
          sshAgentAuth = lib.mkDefault true; # Use SSH_AUTH_SOCK for sudo
        };
      };
    };

    environment.systemPackages = with pkgs; [
      yubioath-flutter # Yubikey authenticator gui
      yubikey-manager # Yubikey manager cli
      yubikey-manager-qt # Yubikey manager gui
      pam_u2f # yubikey with sudo
    ];
  };
}
