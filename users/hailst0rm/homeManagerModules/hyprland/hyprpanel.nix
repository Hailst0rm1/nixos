{
  pkgs,
  lib,
  config,
  nvidiaEnabled,
  ...
}: let
  cfg = config.importConfig.hyprland;
  red = "#f38ba8";
  green = "#a6e3a1";
  text = "#cdd6f4";
  subtext1 = "#bac2de";
  subtext0 = "#a6adc8";
  overlay2 = "#9399b2";
  overlay1 = "#7f849c";
  overlay0 = "#6c7086";
  surface2 = "#585b70";
  surface1 = "#45475a";
  surface0 = "#313244";
  base = "#1e1e2e";
  mantle = "#181825";
  crust = "#11111b";
  white = "#ffffff";
in {
  config = lib.mkIf (cfg.enable && (cfg.panel == "hyprpanel" || cfg.notifications == "hyprpanel")) {
    programs.hyprpanel = {
      enable = true;

      settings = {
        bar.layouts = {
          "*" = {
            left = ["dashboard" "workspaces" "windowtitle"];
            middle = ["clock"];
            right =
              ["media" "kbinput" "volume"]
              ++ ["bluetooth" "network"]
              ++ lib.optionals config.laptop ["battery"]
              ++ ["notifications"];
          };
          "1" = {
            left = ["dashboard" "workspaces" "ram" "cpu" "windowtitle"];
            middle = ["clock"];
            right =
              ["media" "kbinput" "volume"]
              ++ ["bluetooth" "network"]
              ++ lib.optionals config.laptop ["battery"]
              ++ ["notifications"];
          };
        };

        wallpaper.enable = false;

        bar = {
          clock.format = "%a %b %d (w.%V) - %T";
          launcher.autoDetectIcon = true;
          network.label = false;
          bluetooth.label = false;
          media.format = "{title}";
          media.show_active_only = true;
        };

        menus = {
          clock = {
            time.military = true;
            weather.unit = "metric";
            weather.key = "39a8319acbc241bebc492626252001";
            weather.location = config.myLocation;
          };
          dashboard = {
            powermenu.avatar.image = "${config.nixosDir}/assets/images/nixos-logo.png";
            stats.enable_gpu = lib.mkDefault nvidiaEnabled;
            controls.enabled = false;
            shortcuts.enabled = false;
            directories.enabled = false;
          };
          power.lowBatteryNotification = lib.mkDefault (config.laptop);
        };

        theme.osd = {
          location = "bottom";
          margins = "0px 0px 10px 0px";
          orientation = "horizontal";
        };

        # Bar settings
        theme.bar = {
          transparent = true;
          enableShadow = false;
          buttons = {
            enableBorders = false;
            borderSize = "0.05em";
            background_opacity = 80;
            radius = "1em";
          };
        };

        theme.font = {
          name = "${config.stylix.fonts.monospace.name}";
          size = "14px";
        };

        # Catppuccin mocha theme
        "theme.bar.menus.menu.notifications.scrollbar.color" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.notifications.pager.label" = "${overlay2}";
        "theme.bar.menus.menu.notifications.pager.button" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.notifications.pager.background" = "${crust}";
        "theme.bar.menus.menu.notifications.switch.puck" = "${surface2}";
        "theme.bar.menus.menu.notifications.switch.disabled" = "${surface0}";
        "theme.bar.menus.menu.notifications.switch.enabled" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.notifications.clear" = "${red}";
        "theme.bar.menus.menu.notifications.switch_divider" = "${surface1}";
        "theme.bar.menus.menu.notifications.border" = "${surface0}";
        "theme.bar.menus.menu.notifications.card" = "${base}";
        "theme.bar.menus.menu.notifications.background" = "${crust}";
        "theme.bar.menus.menu.notifications.no_notifications_label" = "${surface0}";
        "theme.bar.menus.menu.notifications.label" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.power.buttons.sleep.icon" = "${mantle}";
        "theme.bar.menus.menu.power.buttons.sleep.text" = "#89dceb";
        "theme.bar.menus.menu.power.buttons.sleep.icon_background" = "#89dceb";
        "theme.bar.menus.menu.power.buttons.sleep.background" = "${base}";
        "theme.bar.menus.menu.power.buttons.logout.icon" = "${mantle}";
        "theme.bar.menus.menu.power.buttons.logout.text" = "#a6e3a1";
        "theme.bar.menus.menu.power.buttons.logout.icon_background" = "#a6e3a1";
        "theme.bar.menus.menu.power.buttons.logout.background" = "${base}";
        "theme.bar.menus.menu.power.buttons.restart.icon" = "${mantle}";
        "theme.bar.menus.menu.power.buttons.restart.text" = "#fab387";
        "theme.bar.menus.menu.power.buttons.restart.icon_background" = "#fab387";
        "theme.bar.menus.menu.power.buttons.restart.background" = "${base}";
        "theme.bar.menus.menu.power.buttons.shutdown.icon" = "${mantle}";
        "theme.bar.menus.menu.power.buttons.shutdown.text" = "${red}";
        "theme.bar.menus.menu.power.buttons.shutdown.icon_background" = "#f38ba7";
        "theme.bar.menus.menu.power.buttons.shutdown.background" = "${base}";
        "theme.bar.menus.menu.power.border.color" = "${surface0}";
        "theme.bar.menus.menu.power.background.color" = "${crust}";
        "theme.bar.menus.menu.dashboard.monitors.disk.label" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.monitors.disk.bar" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.monitors.disk.icon" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.monitors.gpu.label" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.monitors.gpu.bar" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.monitors.gpu.icon" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.monitors.ram.label" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.monitors.ram.bar" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.monitors.ram.icon" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.monitors.cpu.label" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.monitors.cpu.bar" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.monitors.cpu.icon" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.monitors.bar_background" = "${surface1}";
        "theme.bar.menus.menu.dashboard.directories.right.bottom.color" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.directories.right.middle.color" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.directories.right.top.color" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.directories.left.bottom.color" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.directories.left.middle.color" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.directories.left.top.color" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.controls.input.text" = "${mantle}";
        "theme.bar.menus.menu.dashboard.controls.input.background" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.controls.volume.text" = "${mantle}";
        "theme.bar.menus.menu.dashboard.controls.volume.background" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.controls.notifications.text" = "${mantle}";
        "theme.bar.menus.menu.dashboard.controls.notifications.background" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.controls.bluetooth.text" = "${mantle}";
        "theme.bar.menus.menu.dashboard.controls.bluetooth.background" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.controls.wifi.text" = "${mantle}";
        "theme.bar.menus.menu.dashboard.controls.wifi.background" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.controls.disabled" = "${surface2}";
        "theme.bar.menus.menu.dashboard.shortcuts.recording" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.shortcuts.text" = "${mantle}";
        "theme.bar.menus.menu.dashboard.shortcuts.background" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.powermenu.confirmation.button_text" = "${crust}";
        "theme.bar.menus.menu.dashboard.powermenu.confirmation.deny" = "${red}";
        "theme.bar.menus.menu.dashboard.powermenu.confirmation.confirm" = "${green}";
        "theme.bar.menus.menu.dashboard.powermenu.confirmation.body" = "${text}";
        "theme.bar.menus.menu.dashboard.powermenu.confirmation.label" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.dashboard.powermenu.confirmation.border" = "${surface0}";
        "theme.bar.menus.menu.dashboard.powermenu.confirmation.background" = "${crust}";
        "theme.bar.menus.menu.dashboard.powermenu.confirmation.card" = "${base}";
        "theme.bar.menus.menu.dashboard.powermenu.sleep" = "#89dceb";
        "theme.bar.menus.menu.dashboard.powermenu.logout" = "${green}";
        "theme.bar.menus.menu.dashboard.powermenu.restart" = "#fab387";
        "theme.bar.menus.menu.dashboard.powermenu.shutdown" = "${red}";
        "theme.bar.menus.menu.dashboard.profile.name" = "${text}";
        "theme.bar.menus.menu.dashboard.border.color" = "${surface0}";
        "theme.bar.menus.menu.dashboard.background.color" = "${crust}";
        "theme.bar.menus.menu.dashboard.card.color" = "${base}";
        "theme.bar.menus.menu.clock.weather.hourly.temperature" = "${text}";
        "theme.bar.menus.menu.clock.weather.hourly.icon" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.clock.weather.hourly.time" = "${text}";
        "theme.bar.menus.menu.clock.weather.thermometer.extremelycold" = "#89dceb";
        "theme.bar.menus.menu.clock.weather.thermometer.cold" = "#89b4fa";
        "theme.bar.menus.menu.clock.weather.thermometer.moderate" = "${green}";
        "theme.bar.menus.menu.clock.weather.thermometer.hot" = "#fab387";
        "theme.bar.menus.menu.clock.weather.thermometer.extremelyhot" = "${red}";
        "theme.bar.menus.menu.clock.weather.stats" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.clock.weather.status" = "${text}";
        "theme.bar.menus.menu.clock.weather.temperature" = "${text}";
        "theme.bar.menus.menu.clock.weather.icon" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.clock.calendar.contextdays" = "${surface2}";
        "theme.bar.menus.menu.clock.calendar.days" = "${text}";
        "theme.bar.menus.menu.clock.calendar.currentday" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.clock.calendar.paginator" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.clock.calendar.weekdays" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.clock.calendar.yearmonth" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.clock.time.timeperiod" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.clock.time.time" = "${text}";
        "theme.bar.menus.menu.clock.text" = "${text}";
        "theme.bar.menus.menu.clock.border.color" = "${surface0}";
        "theme.bar.menus.menu.clock.background.color" = "${crust}";
        "theme.bar.menus.menu.clock.card.color" = "${base}";
        "theme.bar.menus.menu.battery.slider.puck" = "${overlay0}";
        "theme.bar.menus.menu.battery.slider.backgroundhover" = "${surface1}";
        "theme.bar.menus.menu.battery.slider.background" = "${surface0}";
        "theme.bar.menus.menu.battery.slider.primary" = "#f9e2af";
        "theme.bar.menus.menu.battery.icons.active" = "#f9e2af";
        "theme.bar.menus.menu.battery.icons.passive" = "${overlay2}";
        "theme.bar.menus.menu.battery.listitems.active" = "#f9e2af";
        "theme.bar.menus.menu.battery.listitems.passive" = "${text}";
        "theme.bar.menus.menu.battery.text" = "${text}";
        "theme.bar.menus.menu.battery.label.color" = "#f9e2af";
        "theme.bar.menus.menu.battery.border.color" = "${surface0}";
        "theme.bar.menus.menu.battery.background.color" = "${crust}";
        "theme.bar.menus.menu.battery.card.color" = "${base}";
        "theme.bar.menus.menu.systray.dropdownmenu.divider" = "${base}";
        "theme.bar.menus.menu.systray.dropdownmenu.text" = "${text}";
        "theme.bar.menus.menu.systray.dropdownmenu.background" = "${crust}";
        "theme.bar.menus.menu.bluetooth.iconbutton.active" = "#89b4fa";
        "theme.bar.menus.menu.bluetooth.iconbutton.passive" = "${text}";
        "theme.bar.menus.menu.bluetooth.icons.active" = "#89b4fa";
        "theme.bar.menus.menu.bluetooth.icons.passive" = "${overlay2}";
        "theme.bar.menus.menu.bluetooth.listitems.active" = "#89b4fa";
        "theme.bar.menus.menu.bluetooth.listitems.passive" = "${text}";
        "theme.bar.menus.menu.bluetooth.switch.puck" = "${surface2}";
        "theme.bar.menus.menu.bluetooth.switch.disabled" = "${surface0}";
        "theme.bar.menus.menu.bluetooth.switch.enabled" = "#89b4fa";
        "theme.bar.menus.menu.bluetooth.switch_divider" = "${surface1}";
        "theme.bar.menus.menu.bluetooth.status" = "${overlay0}";
        "theme.bar.menus.menu.bluetooth.text" = "${text}";
        "theme.bar.menus.menu.bluetooth.label.color" = "#89b4fa";
        "theme.bar.menus.menu.bluetooth.scroller.color" = "#89b4fa";
        "theme.bar.menus.menu.bluetooth.border.color" = "${surface0}";
        "theme.bar.menus.menu.bluetooth.background.color" = "${crust}";
        "theme.bar.menus.menu.bluetooth.card.color" = "${base}";
        "theme.bar.menus.menu.network.switch.enabled" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.network.switch.disabled" = "${surface0}";
        "theme.bar.menus.menu.network.switch.puck" = "${surface2}";
        "theme.bar.menus.menu.network.iconbuttons.active" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.network.iconbuttons.passive" = "${text}";
        "theme.bar.menus.menu.network.icons.active" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.network.icons.passive" = "${overlay2}";
        "theme.bar.menus.menu.network.listitems.active" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.network.listitems.passive" = "${text}";
        "theme.bar.menus.menu.network.status.color" = "${overlay0}";
        "theme.bar.menus.menu.network.text" = "${text}";
        "theme.bar.menus.menu.network.label.color" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.network.scroller.color" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.network.border.color" = "${surface0}";
        "theme.bar.menus.menu.network.background.color" = "${crust}";
        "theme.bar.menus.menu.network.card.color" = "${base}";
        "theme.bar.menus.menu.volume.input_slider.puck" = "${surface2}";
        "theme.bar.menus.menu.volume.input_slider.backgroundhover" = "${surface1}";
        "theme.bar.menus.menu.volume.input_slider.background" = "${surface0}";
        "theme.bar.menus.menu.volume.input_slider.primary" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.volume.audio_slider.puck" = "${surface2}";
        "theme.bar.menus.menu.volume.audio_slider.backgroundhover" = "${surface1}";
        "theme.bar.menus.menu.volume.audio_slider.background" = "${surface0}";
        "theme.bar.menus.menu.volume.audio_slider.primary" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.volume.icons.active" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.volume.icons.passive" = "${overlay2}";
        "theme.bar.menus.menu.volume.iconbutton.active" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.volume.iconbutton.passive" = "${text}";
        "theme.bar.menus.menu.volume.listitems.active" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.volume.listitems.passive" = "${text}";
        "theme.bar.menus.menu.volume.text" = "${text}";
        "theme.bar.menus.menu.volume.label.color" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.volume.border.color" = "${surface0}";
        "theme.bar.menus.menu.volume.background.color" = "${crust}";
        "theme.bar.menus.menu.volume.card.color" = "${base}";
        "theme.bar.menus.menu.media.slider.puck" = "${overlay0}";
        "theme.bar.menus.menu.media.slider.backgroundhover" = "${surface1}";
        "theme.bar.menus.menu.media.slider.background" = "${surface0}";
        "theme.bar.menus.menu.media.slider.primary" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.media.buttons.text" = "${crust}";
        "theme.bar.menus.menu.media.buttons.background" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.media.buttons.enabled" = "${cfg.accentColourHex}";
        "theme.bar.menus.menu.media.buttons.inactive" = "${surface2}";
        "theme.bar.menus.menu.media.border.color" = "${surface0}";
        "theme.bar.menus.menu.media.card.color" = "${base}";
        "theme.bar.menus.menu.media.background.color" = "${crust}";
        "theme.bar.menus.menu.media.album" = "${text}";
        "theme.bar.menus.menu.media.timestamp" = "${text}";
        "theme.bar.menus.menu.media.artist" = "${text}";
        "theme.bar.menus.menu.media.song" = "${cfg.accentColourHex}";
        "theme.bar.menus.tooltip.text" = "${text}";
        "theme.bar.menus.tooltip.background" = "${crust}";
        "theme.bar.menus.dropdownmenu.divider" = "${base}";
        "theme.bar.menus.dropdownmenu.text" = "${text}";
        "theme.bar.menus.dropdownmenu.background" = "${crust}";
        "theme.bar.menus.slider.puck" = "${overlay0}";
        "theme.bar.menus.slider.backgroundhover" = "${surface1}";
        "theme.bar.menus.slider.background" = "${surface0}";
        "theme.bar.menus.slider.primary" = "${cfg.accentColourHex}";
        "theme.bar.menus.progressbar.background" = "${surface1}";
        "theme.bar.menus.progressbar.foreground" = "${cfg.accentColourHex}";
        "theme.bar.menus.iconbuttons.active" = "${surface2}";
        "theme.bar.menus.iconbuttons.passive" = "${text}";
        "theme.bar.menus.buttons.text" = "${mantle}";
        "theme.bar.menus.buttons.disabled" = "${surface0}";
        "theme.bar.menus.buttons.active" = "${green}";
        "theme.bar.menus.buttons.default" = "${cfg.accentColourHex}";
        "theme.bar.menus.check_radio_button.active" = "${surface2}";
        "theme.bar.menus.check_radio_button.background" = "${surface1}";
        "theme.bar.menus.switch.puck" = "${surface2}";
        "theme.bar.menus.switch.disabled" = "${surface0}";
        "theme.bar.menus.switch.enabled" = "${cfg.accentColourHex}";
        "theme.bar.menus.icons.active" = "${cfg.accentColourHex}";
        "theme.bar.menus.icons.passive" = "${surface2}";
        "theme.bar.menus.listitems.active" = "${cfg.accentColourHex}";
        "theme.bar.menus.listitems.passive" = "${text}";
        "theme.bar.menus.popover.border" = "${mantle}";
        "theme.bar.menus.popover.background" = "${mantle}";
        "theme.bar.menus.popover.text" = "${cfg.accentColourHex}";
        "theme.bar.menus.label" = "${cfg.accentColourHex}";
        "theme.bar.menus.feinttext" = "${surface0}";
        "theme.bar.menus.dimtext" = "${surface2}";
        "theme.bar.menus.text" = "${text}";
        "theme.bar.menus.border.color" = "${surface0}";
        "theme.bar.menus.cards" = "${base}";
        "theme.bar.menus.background" = "${crust}";
        "theme.bar.border.color" = "${cfg.accentColourHex}";
        "theme.bar.background" = "${crust}";
        "theme.bar.buttons.style" = "default";
        "theme.bar.buttons.modules.power.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.power.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.power.background" = "${base}";
        "theme.bar.buttons.modules.power.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.weather.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.weather.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.weather.text" = "${text}";
        "theme.bar.buttons.modules.weather.background" = "${base}";
        "theme.bar.buttons.modules.weather.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.updates.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.updates.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.updates.text" = "${text}";
        "theme.bar.buttons.modules.updates.background" = "${base}";
        "theme.bar.buttons.modules.updates.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.kbLayout.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.kbLayout.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.kbLayout.text" = "${text}";
        "theme.bar.buttons.modules.kbLayout.background" = "${base}";
        "theme.bar.buttons.modules.kbLayout.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.netstat.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.netstat.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.netstat.text" = "${text}";
        "theme.bar.buttons.modules.netstat.background" = "${base}";
        "theme.bar.buttons.modules.netstat.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.storage.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.storage.icon" = "${text}";
        "theme.bar.buttons.modules.storage.text" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.storage.background" = "${base}";
        "theme.bar.buttons.modules.storage.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.cpu.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.cpu.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.cpu.text" = "${text}";
        "theme.bar.buttons.modules.cpu.background" = "${base}";
        "theme.bar.buttons.modules.cpu.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.ram.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.ram.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.ram.text" = "${text}";
        "theme.bar.buttons.modules.ram.background" = "${base}";
        "theme.bar.buttons.modules.ram.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.notifications.total" = "${cfg.accentColourHex}";
        "theme.bar.buttons.notifications.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.notifications.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.notifications.background" = "${base}";
        "theme.bar.buttons.notifications.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.clock.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.clock.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.clock.text" = "${text}";
        "theme.bar.buttons.clock.background" = "${base}";
        "theme.bar.buttons.clock.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.battery.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.battery.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.battery.text" = "${text}";
        "theme.bar.buttons.battery.background" = "${base}";
        "theme.bar.buttons.battery.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.systray.background" = "${base}";
        "theme.bar.buttons.systray.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.systray.customIcon" = "${text}";
        "theme.bar.buttons.bluetooth.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.bluetooth.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.bluetooth.text" = "${text}";
        "theme.bar.buttons.bluetooth.background" = "${base}";
        "theme.bar.buttons.bluetooth.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.network.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.network.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.network.text" = "${text}";
        "theme.bar.buttons.network.background" = "${base}";
        "theme.bar.buttons.network.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.volume.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.volume.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.volume.text" = "${text}";
        "theme.bar.buttons.volume.background" = "${base}";
        "theme.bar.buttons.volume.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.media.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.media.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.media.text" = "${text}";
        "theme.bar.buttons.media.background" = "${base}";
        "theme.bar.buttons.media.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.windowtitle.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.windowtitle.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.windowtitle.text" = "${text}";
        "theme.bar.buttons.windowtitle.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.windowtitle.background" = "${base}";
        "theme.bar.buttons.workspaces.numbered_active_underline_color" = "${cfg.accentColourHex}";
        "theme.bar.buttons.workspaces.numbered_active_highlighted_text_color" = "${mantle}";
        "theme.bar.buttons.workspaces.hover" = "${text}";
        "theme.bar.buttons.workspaces.active" = "${text}";
        "theme.bar.buttons.workspaces.occupied" = "${cfg.accentColourHex}";
        "theme.bar.buttons.workspaces.available" = "${surface2}";
        "theme.bar.buttons.workspaces.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.workspaces.background" = "${base}";
        "theme.bar.buttons.dashboard.icon" = "${white}";
        "theme.bar.buttons.dashboard.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.dashboard.background" = "${base}";
        "theme.bar.buttons.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.text" = "${cfg.accentColourHex}";
        "theme.bar.buttons.hover" = "${surface1}";
        "theme.bar.buttons.icon_background" = "${base}";
        "theme.bar.buttons.background" = "${base}";
        "theme.bar.buttons.borderColor" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.submap.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.submap.background" = "${base}";
        "theme.bar.buttons.modules.submap.icon_background" = "${base}";
        "theme.bar.buttons.modules.submap.text" = "${text}";
        "theme.bar.buttons.modules.submap.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.hyprsunset.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.hyprsunset.background" = "${base}";
        "theme.bar.buttons.modules.hyprsunset.icon_background" = "${base}";
        "theme.bar.buttons.modules.hyprsunset.text" = "${text}";
        "theme.bar.buttons.modules.hyprsunset.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.hypridle.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.hypridle.background" = "${base}";
        "theme.bar.buttons.modules.hypridle.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.hypridle.text" = "${text}";
        "theme.bar.buttons.modules.hypridle.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.cava.text" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.cava.background" = "${base}";
        "theme.bar.buttons.modules.cava.icon_background" = "${base}";
        "theme.bar.buttons.modules.cava.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.cava.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.worldclock.text" = "${text}";
        "theme.bar.buttons.modules.worldclock.background" = "${base}";
        "theme.bar.buttons.modules.worldclock.icon_background" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.worldclock.icon" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.worldclock.border" = "${cfg.accentColourHex}";
        "theme.bar.buttons.modules.microphone.border" = "${green}";
        "theme.bar.buttons.modules.microphone.background" = "${base}";
        "theme.bar.buttons.modules.microphone.text" = "${green}";
        "theme.bar.buttons.modules.microphone.icon" = "${green}";
        "theme.bar.buttons.modules.microphone.icon_background" = "${base}";
        "theme.osd.label" = "${cfg.accentColourHex}";
        "theme.osd.icon" = "${crust}";
        "theme.osd.bar_overflow_color" = "${red}";
        "theme.osd.bar_empty_color" = "${surface0}";
        "theme.osd.bar_color" = "${cfg.accentColourHex}";
        "theme.osd.icon_container" = "${cfg.accentColourHex}";
        "theme.osd.bar_container" = "${crust}";
        "theme.notification.close_button.label" = "${crust}";
        "theme.notification.close_button.background" = "${red}";
        "theme.notification.labelicon" = "${cfg.accentColourHex}";
        "theme.notification.text" = "${text}";
        "theme.notification.time" = "${overlay1}";
        "theme.notification.border" = "${surface0}";
        "theme.notification.label" = "${cfg.accentColourHex}";
        "theme.notification.actions.text" = "${mantle}";
        "theme.notification.actions.background" = "${cfg.accentColourHex}";
        "theme.notification.background" = "${mantle}";
      };
    };
    home.packages = with pkgs; [
      # ---Forced
      ags
      wireplumber
      pipewire
      libgtop
      bluez
      bluez-tools
      networkmanager
      dart-sass
      wl-clipboard
      upower
      gvfs

      # ---Optional

      # Tracking GPU Usage
      python313Packages.gpustat

      # To control screen/keyboard brightness
      brightnessctl

      # Power
      power-profiles-daemon
    ];
  };
}
