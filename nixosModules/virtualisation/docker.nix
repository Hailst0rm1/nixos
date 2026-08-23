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
      # Containers get no working DNS without this. Rootless networking is
      # slirp4netns, whose virtual resolver at 10.0.2.3 forwards to whatever
      # the host uses — and `services.resolved` (nixosModules/services) leaves
      # `127.0.0.53` as the host's only nameserver, which rootlesskit's
      # `--disable-host-loopback` is there to block. The forwarder has nowhere
      # to forward, so every lookup in a container or an image build times out.
      # Naming real upstream resolvers here skips the forwarder entirely.
      # Cost: `.lan` names no longer resolve inside containers — prepend the
      # LAN resolver if a container ever needs them.
      daemon.settings.dns = ["1.1.1.1" "8.8.8.8"];
    };
  };
}
