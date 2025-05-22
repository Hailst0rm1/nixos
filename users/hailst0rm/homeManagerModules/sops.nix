{
  inputs,
  config,
  lib,
  ...
}: {
  imports = [inputs.sops-nix.homeManagerModules.sops];

  options.importConfig.sops.enable = lib.mkEnableOption "Enable User-level sops-nix.";

  config = lib.mkIf config.importConfig.sops.enable {
    sops = {
      age.keyFile = "/home/${config.username}/.config/sops/age/keys.txt";

      defaultSopsFile = ../../../secrets/secrets.yaml; # Maybe make userspecific? secrets/hailst0rm.yaml?
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
        "keys/yubikey/${config.username}" = {
          path = "/home/${config.username}/.config/Yubico/u2f_keys";
        };
      };
    };
  };
}
