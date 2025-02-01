{
  config,
  pkgs,
  lib,
  ...
}: {
  options.security.yubikey.enable = lib.mkEnableOption "Enable yubikey";

  config = lib.mkIf config.security.yubikey.enable {

    security.pam = {
      # MAKE SURE to generate authFile BEFORE enabling this module
      # Generate the file using:
      # `nix-shell -p pam_u2f`
      # `pamu2fcfg > u2f_keys`
      # `sudo mv u2f_keys /etc/Yubico/`
      u2f = {
        enable = lib.mkDefault true;
        authFile = "/etc/Yubico/u2f_keys";
        control = "required";
      };

      services = {
        login.u2fAuth = lib.mkDefault true;
        sudo.u2fAuth = lib.mkDefault true;
      };
    };

    services = {
      # Smart Card support needed for Authenticator app
      pcscd.enable = true;

      # TODO Lock screen if yubikey is removed
    };

    environment.systemPackages = [
      pkgs.pcscliteWithPolkit
      pkgs.yubioath-flutter
    ];
  };
}
