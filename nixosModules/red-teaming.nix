{
  pkgs,
  pkgs-unstable,
  lib,
  config,
  ...
}: {
  config = lib.mkIf config.cyber.redTools.enable {
    # Enable OpenSSH for tunneling etc.
    services.openssh.enable = lib.mkForce true;

    # Want to allow all incoming traffic
    networking = {
      firewall.enable = false;
    };

    # Allow users to bind to privileged ports (< 1024) for red teaming
    boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;

    # Symlink MinGW cross-compiler for Sliver Windows implant generation
    # Sliver looks for /usr/bin/x86_64-w64-mingw32-gcc specifically
    system.activationScripts.sliverMingw = ''
            mkdir -p /usr/bin
            ln -sf ${pkgs.pkgsCross.mingwW64.stdenv.cc}/bin/*-w64-mingw32-* /usr/bin/ 2>/dev/null || true

            # Create a wrapper for gcc that includes library paths
            cat > /usr/bin/x86_64-w64-mingw32-gcc-wrapper << 'EOF'
      #!/bin/sh
      exec ${pkgs.pkgsCross.mingwW64.stdenv.cc}/bin/x86_64-w64-mingw32-gcc \
        -L${pkgs.pkgsCross.mingwW64.windows.mcfgthreads}/lib \
        -L${pkgs.pkgsCross.mingwW64.windows.pthreads}/lib \
        "$@"
      EOF
            chmod +x /usr/bin/x86_64-w64-mingw32-gcc-wrapper
            ln -sf /usr/bin/x86_64-w64-mingw32-gcc-wrapper /usr/bin/x86_64-w64-mingw32-gcc
    '';

    # Legacy BloodHound (Electron viewer, fetched manually) reads this Neo4j.
    services.neo4j = {
      enable = true;
      bolt = {
        tlsLevel = "DISABLED"; # Disable Bolt encryption to avoid the SSL policy error
      };
      https.enable = false;
    };

    # BloodHound CE: web UI at http://127.0.0.1:8090 (Caido owns 8080).
    # Graph lives in Postgres, NOT the Neo4j above: nixpkgs Neo4j is 5+, and
    # CE 8.x's neo4j driver calls db.indexes()/native-btree, Neo4j 4.4 only.
    # First admin password: journalctl -u bloodhound-ce | grep -i password
    services.postgresql = {
      enable = true;
      ensureDatabases = ["bloodhound"];
      ensureUsers = [
        {
          name = "bloodhound";
          ensureDBOwnership = true;
        }
      ];
    };

    environment.etc."bhapi/bhapi.json".text = builtins.toJSON {
      version = 1;
      bind_addr = "127.0.0.1:8090";
      root_url = "http://127.0.0.1:8090/";
      work_dir = "/var/lib/bloodhound-ce";
      graph_driver = "pg";
      # Peer auth over the unix socket: no password to manage.
      database.connection = "user=bloodhound dbname=bloodhound host=/run/postgresql";
      # The legacy "Set ... as High Value" custom queries use SET.
      enable_cypher_mutations = true;
    };

    systemd.services.bloodhound-ce = {
      description = "BloodHound Community Edition";
      wantedBy = ["multi-user.target"];
      requires = ["postgresql.service"];
      after = ["postgresql.service" "postgresql-setup.service"];
      restartTriggers = [config.environment.etc."bhapi/bhapi.json".source];
      serviceConfig = {
        ExecStart = "${pkgs-unstable.bloodhound-ce}/bin/bloodhound-ce";
        # Peer auth maps the uid to the "bloodhound" Postgres role.
        DynamicUser = true;
        User = "bloodhound";
        StateDirectory = "bloodhound-ce";
        Restart = "on-failure";
      };
    };

    # Replaced with lingolo-ng
    # Configure proxy using proxychains for red-teaming lateral movement
    programs.proxychains = lib.mkIf config.cyber.redTools.enable {
      enable = false; # Set to true to reactivate
      package = pkgs.proxychains-ng;
      quietMode = false;
      proxies = {
        pen-200 = {
          enable = true;
          type = "http";
          host = "192.168.145.224";
          port = 3128;
        };
      };
    };

    # Override the generated config to add credentials
    # environment.etc."proxychains.conf" = lib.mkIf config.cyber.redTools.enable {
    #   text = lib.mkForce ''
    #     strict_chain
    #     quiet_mode
    #     tcp_read_time_out 15000
    #     tcp_connect_time_out 8000

    #     [ProxyList]
    #     http 192.168.145.224 3128 ext_acc DoNotShare!SkyLarkLegacyInternal2008
    #   '';
    # };
  };
}
