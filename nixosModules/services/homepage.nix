{
  config,
  lib,
  ...
}: let
  cfg = config.services.homepage-dashboard;
in {
  options.services.homepage-dashboard = {
    myServices = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf (lib.types.attrsOf lib.types.anything));
      default = [];
      description = "Additional homepage service blocks.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.glances.enable = true;
    services.homepage-dashboard = {
      customCSS = ''
        body, html {
          font-family: SF Pro Display, Helvetica, Arial, sans-serif !important;
        }
        .font-medium {
          font-weight: 700 !important;
        }
        .font-light {
          font-weight: 500 !important;
        }
        .font-thin {
          font-weight: 400 !important;
        }
        #information-widgets {
          padding-left: 1.5rem;
          padding-right: 1.5rem;
        }
        div#footer {
          display: none;
        }
        .services-group.basis-full.flex-1.px-1.-my-1 {
          padding-bottom: 3rem;
        };
      '';

      settings = {
        layout = [
          {
            Glances = {
              header = false;
              style = "row";
              columns = 4;
            };
          }
          # {
          #   Arr = {
          #     header = true;
          #     style = "column";
          #   };
          # }
          # {
          #   Downloads = {
          #     header = true;
          #     style = "column";
          #   };
          # }
          # {
          #   Media = {
          #     header = true;
          #     style = "column";
          #   };
          # }
          # {
          #   Services = {
          #     header = true;
          #     style = "column";
          #   };
          # }
        ];
        headerStyle = "clean";
        statusStyle = "dot";
        hideVersion = "true";
      };
      services =
        config.services.homepage-dashboard.myServices
        ++ [
          {
            Glances = let
              port = toString config.services.glances.port;
            in [
              {
                Info = {
                  widget = {
                    type = "glances";
                    url = "http://localhost:${port}";
                    metric = "info";
                    chart = false;
                    version = 4;
                  };
                };
              }
              {
                "CPU Temp" = {
                  widget = {
                    type = "glances";
                    url = "http://localhost:${port}";
                    metric = "sensor:Package id 0";
                    chart = false;
                    version = 4;
                  };
                };
              }
              {
                Processes = {
                  widget = {
                    type = "glances";
                    url = "http://localhost:${port}";
                    metric = "process";
                    chart = false;
                    version = 4;
                  };
                };
              }
              {
                Network = {
                  widget = {
                    type = "glances";
                    url = "http://localhost:${port}";
                    metric = "network:enp2s0";
                    chart = false;
                    version = 4;
                  };
                };
              }
            ];
          }
        ];
    };
  };
}
