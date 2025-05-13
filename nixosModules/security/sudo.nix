{ config, ... }: {
  config = {
    security.sudo.extraConfig = ''
      Defaults:${config.username} timestamp_timeout=-1
    '';
  };
}
