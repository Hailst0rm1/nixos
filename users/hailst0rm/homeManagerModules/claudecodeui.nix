{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.claudecodeui;

  pluginsDir = "${config.home.homeDirectory}/.claude-code-ui/plugins";

  terminalShellWrapper = pkgs.writeShellScript "cloudcli-terminal-shell" ''
    export USER="$(id -un)"
    [ -e /etc/set-environment ] && . /etc/set-environment
    export SHELL="${cfg.shell}"
    exec "${cfg.shell}" -l "$@"
  '';

  terminalLockfile = builtins.toFile "package-lock.json" (builtins.readFile ./claudecodeui-terminal-lockfile.json);

  # Build plugins using buildNpmPackage for proper dep fetching
  pluginProject = pkgs.buildNpmPackage {
    pname = "claudecodeui-plugin-project-stats";
    version = "unstable";
    src = pkgs.fetchFromGitHub {
      owner = "cloudcli-ai";
      repo = "cloudcli-plugin-starter";
      rev = "main";
      hash = "sha256:094ikicfgs4hmzk0iz0kz3j692bq3k5cp7vmcwqanfzp5q17fk1x";
    };
    npmDepsHash = "sha256-GKCSkCy49x+5QpnD4RNacU+r9LIvcVAvJoT0IyYQp0Y=";
    npmFlags = ["--ignore-scripts"];
    dontNpmBuild = false;
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out/
      rm -rf $out/.git $out/.github
      runHook postInstall
    '';
    dontFixup = true;
    meta.description = "Claude Code UI Project Stats plugin";
  };

  pluginTerminal = pkgs.buildNpmPackage {
    pname = "claudecodeui-plugin-web-terminal";
    version = "unstable";
    src = pkgs.fetchFromGitHub {
      owner = "cloudcli-ai";
      repo = "cloudcli-plugin-terminal";
      rev = "main";
      hash = "sha256:1jld0pw487lk0nsf4np5azjr1yvfq6z80m5f7dql00z1l6wp2r0l";
    };
    postPatch = ''
      cp ${terminalLockfile} package-lock.json
      # NixOS: use a wrapper script that sources /etc/set-environment for full env
      substituteInPlace src/server.ts \
        --replace-fail "process.env.SHELL || '/bin/bash'" "'${terminalShellWrapper}'"
    '';
    npmDepsHash = "sha256-X5aIgKXy9QrdfGNBhTiRhzeUMKYtIkY/nK9Orbbg8O0=";
    npmFlags = ["--ignore-scripts"];
    nativeBuildInputs = [pkgs.python3 pkgs.pkg-config];
    buildInputs = [pkgs.pixman pkgs.cairo pkgs.pango pkgs.giflib pkgs.libjpeg pkgs.librsvg];
    dontNpmBuild = false;
    postBuild = ''
      npm rebuild node-pty 2>/dev/null || true
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out/
      rm -rf $out/.git $out/.github
      runHook postInstall
    '';
    dontFixup = true;
    meta.description = "Claude Code UI Web Terminal plugin";
  };

  pluginScheduler = pkgs.buildNpmPackage {
    pname = "claudecodeui-plugin-scheduler";
    version = "unstable";
    src = pkgs.fetchFromGitHub {
      owner = "grostim";
      repo = "cloudcli-cron";
      rev = "master";
      hash = "sha256:1pndqg7p1lgclwrqxq3552lfw26y4dgmipxrprx95mglpfax7sdj";
    };
    npmDepsHash = "sha256-8tHb2OI/TIjqoh7Qv+xFXVpW2HAGnSUQvbS4BCGsGYs=";
    npmFlags = ["--ignore-scripts"];
    dontNpmBuild = false;
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out/
      rm -rf $out/.git $out/.github
      runHook postInstall
    '';
    dontFixup = true;
    meta.description = "Claude Code UI Scheduler plugin";
  };

  enabledPlugins =
    lib.optionalAttrs cfg.plugins.project-stats.enable {"project-stats" = pluginProject;}
    // lib.optionalAttrs cfg.plugins.web-terminal.enable {"web-terminal" = pluginTerminal;}
    // lib.optionalAttrs cfg.plugins.scheduler.enable {"workspace-scheduled-prompts" = pluginScheduler;};

  pluginsConfig = builtins.toJSON (
    lib.mapAttrs (_: _: true) enabledPlugins
  );

  pluginActivation = pkgs.writeShellScript "claudecodeui-plugins" ''
    mkdir -p "${pluginsDir}"

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: drv: ''
        target="${pluginsDir}/${name}"
        if [ ! -d "$target" ] || [ "$(readlink -f "$target/.nix-source" 2>/dev/null)" != "${drv}" ]; then
          rm -rf "$target"
          cp -r "${drv}" "$target"
          chmod -R u+w "$target"
          ln -sf "${drv}" "$target/.nix-source"
        fi
      '')
      enabledPlugins)}

    cat > "${config.home.homeDirectory}/.claude-code-ui/plugins.json" <<'CONFIGEOF'
    ${pluginsConfig}
    CONFIGEOF
  '';
in {
  options.services.claudecodeui = {
    enable = mkEnableOption "Claude Code UI - Web UI for Claude Code";

    port = mkOption {
      type = types.port;
      default = 3001;
      description = "Port to run Claude Code UI on";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host/IP to bind the server to";
    };

    shell = mkOption {
      type = types.str;
      default = "${pkgs.zsh}/bin/zsh";
      description = "Shell to use for the web terminal";
    };

    plugins = {
      project-stats = {
        enable = mkEnableOption "Project Stats plugin" // {default = true;};
      };
      web-terminal = {
        enable = mkEnableOption "Web Terminal plugin" // {default = true;};
      };
      scheduler = {
        enable = mkEnableOption "CloudCLI Scheduler plugin" // {default = true;};
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.claudecodeui];

    home.activation.claudecodeui-plugins = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run ${pluginActivation}
    '';

    systemd.user.startServices = "sd-switch";

    systemd.user.services.claudecodeui = {
      Unit = {
        Description = "Claude Code UI - Web UI for Claude Code";
        After = ["graphical-session.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.claudecodeui}/bin/cloudcli start";
        Restart = "on-failure";
        RestartSec = "5s";

        Environment = [
          "SERVER_PORT=${toString cfg.port}"
          "HOST=${cfg.host}"
          "NODE_ENV=production"
          "CLAUDE_CLI_PATH=${config.home.profileDirectory}/bin/claude"
          "SHELL=${cfg.shell}"
          "PATH=${config.home.profileDirectory}/bin:/run/wrappers/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin"
        ];

        LimitNOFILE = "65536";
      };

      Install = {
        WantedBy = ["default.target"];
      };
    };
  };
}
