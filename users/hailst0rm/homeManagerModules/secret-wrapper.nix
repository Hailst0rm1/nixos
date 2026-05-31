{
  config,
  lib,
  pkgs,
  ...
}: let
  # Resolve a sops secret key to its on-disk path: the HM sops mount when
  # user-level sops is enabled, otherwise the NixOS-level /run/secrets mount.
  secretPath = key:
    if config.importConfig.sops.enable
    then config.sops.secrets.${key}.path
    else "/run/secrets/${key}";

  # Build a wrapper that exports secrets into the environment and execs a command.
  #   env       — attrset of ENV_VAR -> sops secret key (read at runtime if present)
  #   staticEnv — attrset of ENV_VAR -> literal value
  #   command   — the program to exec ("$@" is appended)
  #   bin       — true puts a named binary on PATH (writeShellScriptBin)
  mkSecretEnvWrapper = {
    name,
    command,
    env ? {},
    staticEnv ? {},
    bin ? false,
  }: let
    secretExports = lib.concatStrings (lib.mapAttrsToList (var: key: ''
        __sw_file="${secretPath key}"
        if [ -f "$__sw_file" ]; then
          export ${var}="$(cat "$__sw_file")"
        fi
      '')
      env);
    staticExports = lib.concatStrings (lib.mapAttrsToList (var: value: ''
        export ${var}=${lib.escapeShellArg value}
      '')
      staticEnv);
    builder =
      if bin
      then pkgs.writeShellScriptBin name
      else pkgs.writeShellScript name;
  in
    builder ''
      ${secretExports}${staticExports}exec ${command} "$@"
    '';
in {
  _module.args = {inherit secretPath mkSecretEnvWrapper;};
}
