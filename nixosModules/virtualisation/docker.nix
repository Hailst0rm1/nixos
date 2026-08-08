{
  config,
  lib,
  ...
}: let
  cfg = config.virtualisation.host.docker;
in {
  options.virtualisation.host.docker = lib.mkEnableOption "Enable rootless docker host";

  config = lib.mkIf cfg {
    # Rootless: the daemon runs as the login user, so there is no
    # root-equivalent `docker` group to join. The CLI package (which bundles
    # the compose + buildx plugins) is installed by the upstream module.
    virtualisation.docker.rootless = {
      enable = true;
      # DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock for normal users.
      setSocketVariable = true;
    };
  };
}
