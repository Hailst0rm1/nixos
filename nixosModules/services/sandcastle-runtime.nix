# Bridge: enable the container runtime sandcastle needs.
#
# `code.sandcastle` is a Home-Manager option, but `virtualisation.podman` /
# `virtualisation.docker` are NixOS-level — HM can read `osConfig` but can't
# set NixOS options. This NixOS module reads the evaluated HM config and turns
# on the runtime ONLY for hosts where some user has sandcastle enabled, so
# podman/docker is never pulled into the closure of hosts that don't run it.
{
  config,
  lib,
  ...
}: let
  # Guarded: hosts without Home-Manager have no `config.home-manager`.
  hmUsers = lib.attrByPath ["home-manager" "users"] {} config;
  sandcastleUsers =
    lib.filter (u: u.code.sandcastle.enable or false) (lib.attrValues hmUsers);
  wants = runtime:
    lib.any (u: (u.code.sandcastle.container or "podman") == runtime) sandcastleUsers;
in {
  config = lib.mkMerge [
    # Reuse the repo's podman wrapper (dockerCompat + autoPrune already configured).
    (lib.mkIf (wants "podman") {services.podman.enable = true;})
    (lib.mkIf (wants "docker") {virtualisation.docker.enable = true;})
  ];
}
