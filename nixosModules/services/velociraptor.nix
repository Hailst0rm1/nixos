{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.velociraptor;
  stateDir = "/var/lib/velociraptor";
  configFile = "${stateDir}/server.config.yaml";
  # Only read when the config is first generated. Change a value later and
  # you must delete ${configFile} (certs get re-issued) for it to apply.
  mergeJson = builtins.toJSON {
    Datastore = {
      location = stateDir;
      filestore_directory = stateDir;
    };
    GUI = {
      bind_address = cfg.bindAddress;
      bind_port = cfg.guiPort;
    };
    Frontend = {
      bind_address = cfg.bindAddress;
      bind_port = cfg.frontendPort;
    };
  };
in {
  options.services.velociraptor = {
    enable = lib.mkEnableOption "Velociraptor DFIR server";

    package = lib.mkPackageOption pkgs "velociraptor" {};

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address the GUI and the client frontend listen on.";
    };

    guiPort = lib.mkOption {
      type = lib.types.port;
      default = 8889;
      description = "Port of the web GUI (https).";
    };

    frontendPort = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Port that Velociraptor clients connect to.";
    };

    openFirewall = lib.mkEnableOption "opening the GUI and frontend ports in the firewall";
  };

  config = lib.mkIf cfg.enable {
    users.users.velociraptor = {
      isSystemUser = true;
      group = "velociraptor";
      home = stateDir;
    };
    users.groups.velociraptor = {};

    # Create the first admin with:
    #   sudo -u velociraptor velociraptor --config /var/lib/velociraptor/server.config.yaml user add <name> --role administrator
    environment.systemPackages = [cfg.package];

    systemd.services.velociraptor = {
      description = "Velociraptor server";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      path = [cfg.package];
      preStart = ''
        if [ ! -e ${configFile} ]; then
          velociraptor config generate --merge '${mergeJson}' > ${configFile}.tmp
          mv ${configFile}.tmp ${configFile}
        fi
      '';
      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} --config ${configFile} frontend -v";
        User = "velociraptor";
        Group = "velociraptor";
        StateDirectory = "velociraptor";
        StateDirectoryMode = "0700";
        UMask = "0077";
        Restart = "on-failure";
        # Needs to open many client connections / datastore files
        LimitNOFILE = 65536;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.guiPort cfg.frontendPort];
  };
}
