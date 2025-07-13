{
  config,
  lib,
  pkgs-unstable,
  ...
}: let
  cfg = config.importConfig.yazi;
in {
  options.importConfig.yazi.enable = lib.mkEnableOption "Enable Yazi file manager.";

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      package = pkgs-unstable.yazi;
      enableZshIntegration = true;

      plugins = {
        git = pkgs-unstable.yaziPlugins.git;
      };

      theme = {
        input.border = lib.mkForce {fg = "${config.importConfig.hyprland.accentColourHex}";};
        mode = {
          normal_alt = lib.mkForce {
            fg = "${config.importConfig.hyprland.accentColourHex}";
            bg = "#181825";
          };
          normal_main = lib.mkForce {
            fg = "#181825";
            bg = "${config.importConfig.hyprland.accentColourHex}";
          };
          select_alt = lib.mkForce {
            fg = "#a6e3a1";
            bg = "#181825";
          };
          select_main = lib.mkForce {
            fg = "#181825";
            bg = "#a6e3a1";
          };
        };
        pick.border = lib.mkForce {fg = "${config.importConfig.hyprland.accentColourHex}";};
        status.perm_type = lib.mkForce {fg = "${config.importConfig.hyprland.accentColourHex}";};
        tasks.border = lib.mkForce {fg = "${config.importConfig.hyprland.accentColourHex}";};
        tabs = {
          active = {bg = "${config.importConfig.hyprland.accentColourHex}";};
          inactive = {
            bg = "#181825";
            fg = "${config.importConfig.hyprland.accentColourHex}";
          };
        };
        filetype = lib.mkForce {
          rules = [
            {
              fg = "${config.importConfig.hyprland.accentColourHex}";
              mime = "inode/directory";
              bold = true;
            }
          ];
        };
        status = {
          separator_open = "█";
          separator_close = "█";
        };
      };
      initLua = ''
        require("git"):setup()
      '';

      settings = {
        mgr = {
          ratio = [2 2 4];
          show_hidden = true;
        };
        plugin.prepend_fetchers = [
          {
            id = "git";
            name = "*";
            run = "git";
          }
          {
            id = "git";
            name = "*/";
            run = "git";
          }
        ];
      };
    };
  };
}
