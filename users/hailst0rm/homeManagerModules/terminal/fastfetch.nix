{
  pkgs-unstable,
  lib,
  config,
  ...
}: {
  config = lib.mkIf (config.shell == "zsh") {
    programs.fastfetch = {
      enable = true;
      package = pkgs-unstable.fastfetch;
      settings = {
        logo = {
          padding.top = 1;
          source = "${../wallpapers/nixos-logo.png}";
          height = 22;
        };
        display = {
          separator = " -> ";
        };
        modules = [
          "break"
          {
            type = "custom";
            format = "{#31}┌───────────────  | OS Info ───────────────┐";
          }
          {
            type = "command";
            key = "   OS";
            keyColor = "red";
            text = "hostnamectl | grep 'Operating System' | cut -f2 -d ':'";
          }
          {
            type = "os";
            key = "   OS";
            keyColor = "red";
          }
          {
            type = "kernel";
            key = "   Kernel";
            keyColor = "red";
          }
          {
            type = "packages";
            key = "   Pkgs";
            keyColor = "red";
          }
          {
            type = "custom";
            format = "{#31}└───────────────────────────────────────────┘";
          }
          "break"
          {
            type = "custom";
            format = "{#32}┌──────────────  | User Info ──────────────┐";
          }
          {
            type = "command";
            key = "   Username";
            keyColor = "green";
            text = "whoami";
          }
          {
            type = "WM";
            key = "  󰖲 WM";
            keyColor = "green";
          }
          {
            type = "theme";
            key = "   Theme";
            keyColor = "green";
          }
          {
            type = "terminal";
            key = "   Term";
            keyColor = "green";
          }
          {
            type = "custom";
            format = "{#32}└───────────────────────────────────────────┘";
          }
          "break"
          {
            type = "custom";
            format = "{#34}┌─────────────── 󰋊 | HW Info ───────────────┐";
          }
          {
            type = "command";
            key = "   CPU";
            keyColor = "blue";
            text = "echo $(lscpu | grep 'Model name' | cut -f31 -d ' ') $(lscpu | grep 'Model name' | cut -f32 -d ' ') $(lscpu | grep 'Model name' | cut -f33 -d ' ')";
          }
          {
            type = "gpu";
            format = "{2}";
            key = "   GPU";
            keyColor = "blue";
          }
          {
            type = "gpu";
            format = "{3}";
            key = "  └  Drv";
            keyColor = "blue";
          }
          {
            type = "memory";
            key = "   Memory";
            keyColor = "blue";
          }
          {
            type = "command";
            key = "  󱦟 OS Age ";
            keyColor = "34";
            text = "birth_install=$(stat -c %W /); current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days";
          }
          {
            type = "uptime";
            key = "  󱫐 Uptime ";
            keyColor = "blue";
          }
          {
            type = "custom";
            format = "{#34}└───────────────────────────────────────────┘";
          }
          {
            type = "colors";
            paddingLeft = 15;
            symbol = "circle";
          }
          "break"
        ];
      };
    };
  };
}
