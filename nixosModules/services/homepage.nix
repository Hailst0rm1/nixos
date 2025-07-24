{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.services.homepage-dashboard;
  backgroundFile = builtins.baseNameOf config.services.homepage-dashboard.background;
  iconFile = builtins.baseNameOf config.services.homepage-dashboard.icon;
  package = pkgs.homepage-dashboard.overrideAttrs (oldAttrs: {
    postInstall = ''
      mkdir -p $out/share/homepage/public/images
      ln -s ${config.services.homepage-dashboard.background} $out/share/homepage/public/images/${backgroundFile}
      ln -s ${config.services.homepage-dashboard.icon} $out/share/homepage/public/images/${iconFile}
    '';
  });
in {
  options.services.homepage-dashboard = {
    background = lib.mkOption {
      type = lib.types.path; # Accepts a file path
      description = "Path to a icon file.";
      example = ./logo.png;
    };
    icon = lib.mkOption {
      type = lib.types.path; # Accepts a file path
      description = "Path to a icon file.";
      example = ./logo.png;
    };
    colour = lib.mkOption {
      type = lib.types.enum [
        "gray"
        "zinc"
        "neutral"
        "stone"
        "amber"
        "lime"
        "emerald"
        "cyan"
        "indigo"
        "violet"
        "purple"
        "fuchsia"
        "rose"
        "white"
        "pink"
        "red"
        "yellow"
        "green"
        "teal"
        "slate"
        "blue"
      ];
      default = "gray";
      description = "The accent colour for the homepage.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.homepage-dashboard = {
      package = package;
      allowedHosts = "home.${config.services.domain}";
      widgets = [
        {
          logo.icon = "/images/${iconFile}";
        }
        {
          resources = {
            cpu = true;
            disk = "/";
            memory = true;
          };
        }
        {
          search = {
            provider = "google";
            focus = true;
            showSearchSuggestions = true;
            target = "_self";
          };
        }
        {
          openmeteo = {
            units = "metric";
            cache = "5";
          };
        }
      ];

      settings = {
        background = {
          image = "/images/${backgroundFile}";
          blur = "sm";
          saturate = "75";
          brightness = "75";
          opacity = "50";
        };
        theme = "dark";
        iconStyle = "theme";
        useEqualHeights = true;
        color = config.services.homepage-dashboard.colour;
        disableCollapse = true;
        headerStyle = "underlined";
        target = "_self";
        hideVersion = "true";
        statusStyle = "dot";
      };
    };
  };
}
