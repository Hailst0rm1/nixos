{
  lib,
  config,
  ...
}: {
  # System-level side of cyber.dfir.enable (option declared in variables.nix).
  # Mirrors the red-teaming.nix pattern: the NixOS host owns the system bits,
  # the Home Manager module (users/*/homeManagerModules/cyber/dfir.nix) follows
  # via osConfig for the per-user tooling and lab scripts.
  config = lib.mkIf config.cyber.dfir.enable {
    # Guarantee VirtualBox is present when DFIR is enabled. This does not seize
    # the repo-wide default (still true in hosts/default.nix) — it only ensures
    # the analysis lab always has a hypervisor available.
    virtualisation.host.virtualbox = true;
  };
}
