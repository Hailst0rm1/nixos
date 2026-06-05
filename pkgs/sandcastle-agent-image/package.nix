# Sandcastle agent sandbox image (rootless Podman).
#
# A THIN OCI image: it bakes only the agent *toolchain* (claude, codex, node,
# git, gh, …) as a nix `buildEnv` on PATH. It deliberately does NOT bake your
# skills/plugins or any project's devShell — those arrive at runtime:
#
#   • ~/.claude skill/plugin/agent content  → bind-mounted read-only by the
#     orchestrator (symlinks into /nix/store resolve because the host store is
#     also mounted).
#   • the host /nix/store                    → bind-mounted read-only. Because
#     this image is built from the same nixpkgs, its store paths are a SUBSET
#     of the host's, so mounting the host store over /nix/store loses nothing
#     and gains every project's already-built devShell (Node, Postgres, …).
#
# Build + load into Podman:
#   nix build .#sandcastle-agent-image
#   podman load < result
{
  lib,
  dockerTools,
  buildEnv,
  bashInteractive,
  coreutils,
  gnused,
  gnugrep,
  findutils,
  which,
  gitMinimal,
  gh,
  jq,
  ripgrep,
  cacert,
  nix,
  nodejs_22,
  # Passed from flake.nix (flake inputs, not in nixpkgs):
  claude-code,
  codex,
}: let
  # Everything the agent + the skills' shell-outs need on PATH.
  agentEnv = buildEnv {
    name = "sandcastle-agent-env";
    paths = [
      claude-code
      codex
      nodejs_22
      gitMinimal
      gh
      jq
      ripgrep
      bashInteractive
      coreutils
      gnused
      gnugrep
      findutils
      which
      nix
      cacert
    ];
  };
in
  dockerTools.buildLayeredImage {
    name = "sandcastle-agent";
    tag = "latest";

    contents = [
      agentEnv
      # /bin/sh and /usr/bin/env for tools that shell out.
      dockerTools.binSh
      dockerTools.usrBinEnv
    ];

    # The sandcastle podman provider runs the container as `--user 1000:1000`
    # with `--userns=keep-id` and `HOME=/home/agent`. So the image MUST contain
    # an `agent` user (uid 1000) owning a writable /home/agent, plus passwd/group
    # so username lookups (git, gh) resolve. We hand-roll /etc rather than use
    # dockerTools.fakeNss (which only knows root/nobody).
    #
    # Other writable dirs: /tmp scratch; /nix/var for an in-container nix's state
    # (the store itself arrives via the host's read-only /nix/store bind mount).
    extraCommands = ''
      mkdir -p tmp && chmod 1777 tmp
      mkdir -p nix/var/nix
      mkdir -p home/agent && chmod 0777 home/agent
      mkdir -p etc
      cat > etc/passwd <<'EOF'
      root:x:0:0:root:/root:/bin/sh
      agent:x:1000:1000:agent:/home/agent:/bin/sh
      EOF
      cat > etc/group <<'EOF'
      root:x:0:
      agent:x:1000:
      EOF
      cat > etc/nsswitch.conf <<'EOF'
      passwd: files
      group: files
      hosts: files dns
      EOF
    '';

    config = {
      Env = [
        "PATH=${agentEnv}/bin:/bin:/usr/bin"
        "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
        "NIX_SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
        "GIT_SSL_CAINFO=${cacert}/etc/ssl/certs/ca-bundle.crt"
        # Let claude/npm/etc. find a HOME even before the orchestrator overrides it.
        "HOME=/home/agent"
        "LANG=C.UTF-8"
      ];
      WorkingDir = "/workspace";
      Cmd = ["${bashInteractive}/bin/bash"];
    };
  }
