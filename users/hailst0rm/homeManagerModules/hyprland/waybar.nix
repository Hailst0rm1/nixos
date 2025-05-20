{ lib, config, ... }: {

    config = lib.mkIf (config.importConfig.hyprland.panel == "waybar") {
        wayland.windowManager.hyprland.settings.exec-once = [ "waybar" ];
        home.file.".config/waybar/config.jsonc".text = ''
    {
        "layer": "top",
        "position": "top",
        "mod": "dock",
        "exclusive": true,
        "passthrough": false,
        "gtk-layer-shell": true,
        "height": 50,
        "modules-left": [
            "clock",
            "custom/weather",
            "custom/moon",
            "custom/wall",
            "hyprland/workspaces"
        ],
        "modules-center": [
            "hyprland/window"
        ],
        "modules-right": [
            "network",
            "bluetooth",
            "custom/temperature",
            "custom/memory",
            "battery",
            "backlight",
            "pulseaudio",
            "pulseaudio#microphone"
        ],
        "hyprland/workspaces": {
            "format": "{icon}",
            "on-scroll-up": "hyprctl dispatch workspace e+1",
            "on-scroll-down": "hyprctl dispatch workspace e-1",
            "format-icons": {
                "1": "😎",
                "2": "🌐",
                "3": "👩🏽‍💻",
                "4": "📒",
                "5": "🎵"
            },
            "persistent_workspaces": {
                "*": 1
            }
        },
        "hyprland/window": {
            "format": "{}"
        },
        "custom/weather": {
            "tooltip": true,
            "format": "{}",
            "interval": 3600,
            "exec": "~/.config/waybar/scripts/waybar-wttr.py",
            "return-type": "json"
        },
        "custom/moon": {
            "format": "{}",
            "interval": 3600,
            "exec": "moon"
        },

        "custom/wall":{
            "format": "{}",
            "interval":60,
            "exec":"r-wall & ",
            "format-alt":"r-wall &"
        },

        "custom/temperature": {
            "tooltip": true,
            "format": " {}",
            "interval": 30,
            "exec": "cpu"
        },
        "custom/memory": {
            "tooltip": true,
            "format": "🧠 {}",
            "interval": 30,
            "exec": "memory"
        },
        "tray": {
            "icon-size": 18,
            "spacing": 10
        },
        "clock": {
            "format": "{: %I:%M %p  %a, %b %e}",
            "tooltip-format": "<big>{:%Y %B}</big>\n<tt>{calendar}</tt>"
        },
        "backlight": {
            "device": "intel_backlight",
            "format": "{icon} {percent}%",
            "format-icons": [
                "󰃞",
                "󰃟",
                "󰃠"
            ],
            "on-scroll-up": "brightnessctl -q set 1%+",
            "on-scroll-down": "brightnessctl -q set 1%-"
        },
        "battery": {
            "states": {
                "good": 95,
                "warning": 40,
                "critical": 30
            },
            "format": "{icon} {capacity}%",
            "format-charging": " {capacity}%",
            "format-plugged": " {capacity}%",
            "format-alt": "{time} {icon}",
            "format-icons": [
                "󰂎",
                "󰁺",
                "󰁻",
                "󰁼",
                "󰁽",
                "󰁾",
                "󰁿",
                "󰂀",
                "󰂁",
                "󰂂",
                "󰁹"
            ]
        },
        "pulseaudio": {
            "format": "{icon} {volume}%",
            "tooltip": false,
            "format-muted": " Muted",
            "on-click": "pamixer -t",
            "on-scroll-up": "pamixer -i 5",
            "on-scroll-down": "pamixer -d 5",
            "scroll-step": 100,
            "format-icons": {
                "headphone": "",
                "hands-free": "",
                "headset": "",
                "phone": "",
                "portable": "",
                "car": "",
                "default": [
                    "",
                    "",
                    ""
                ]
            }
        },
        "pulseaudio#microphone": {
            "format": "{format_source}",
            "format-source": " {volume}%",
            "format-source-muted": " Muted",
            "on-click": "pamixer --default-source -t",
            "on-scroll-up": "pamixer --default-source -i 5",
            "on-scroll-down": "pamixer --default-source -d 5",
            "scroll-step": 5
        },
        "network": {
            "format-wifi": "  {signalStrength}%",
            "format-ethernet": "{ipaddr}/{cidr}",
            "tooltip-format": "{essid} - {ifname} via {gwaddr}",
            "format-linked": "{ifname} (No IP)",
            "format-disconnected": "Disconnected ⚠",
            "format-alt": "{ifname}:{essid} {ipaddr}/{cidr}"
        },
        "bluetooth": {
            "format": " {status}",
            "format-disabled": "", // an empty format will hide the module
            "format-connected": " {num_connections}",
            "tooltip-format": "{device_alias}",
            "tooltip-format-connected": " {device_enumerate}",
            "tooltip-format-enumerate-connected": "{device_alias}"
        }
    }
      '';

      home.file.".config/waybar/style.css".text = ''
    @import "mocha.css";

    * {
      font-family: FantasqueSansMono Nerd Font;
      font-size: 17px;
      min-height: 0;
    }

    #waybar {
      background: transparent;
      color: @text;
      margin: 5px 5px;
    }

    #workspaces {
      border-radius: 1rem;
      margin: 5px;
      background-color: @surface0;
      margin-left: 1rem;
    }

    #workspaces button {
      color: @lavender;
      border-radius: 1rem;
      padding: 0.4rem;
    }

    #workspaces button.active {
      color: @sky;
      border-radius: 1rem;
    }

    #workspaces button:hover {
      color: @sapphire;
      border-radius: 1rem;
    }

    #custom-music,
    #tray,
    #backlight,
    #clock,
    #battery,
    #pulseaudio,
    #custom-lock,
    #custom-power {
      background-color: @surface0;
      padding: 0.5rem 1rem;
      margin: 5px 0;
    }

    #clock {
      color: @blue;
      border-radius: 0px 1rem 1rem 0px;
      margin-right: 1rem;
    }

    #battery {
      color: @green;
    }

    #battery.charging {
      color: @green;
    }

    #battery.warning:not(.charging) {
      color: @red;
    }

    #backlight {
      color: @yellow;
    }

    #backlight, #battery {
        border-radius: 0;
    }

    #pulseaudio {
      color: @maroon;
      border-radius: 1rem 0px 0px 1rem;
      margin-left: 1rem;
    }

    #custom-music {
      color: @mauve;
      border-radius: 1rem;
    }

    #custom-lock {
        border-radius: 1rem 0px 0px 1rem;
        color: @lavender;
    }

    #custom-power {
        margin-right: 1rem;
        border-radius: 0px 1rem 1rem 0px;
        color: @red;
    }

    #tray {
      margin-right: 1rem;
      border-radius: 1rem;
    }
      '';

      home.file.".config/waybar/mocha.css".text = ''
    @define-color rosewater #f5e0dc;
    @define-color flamingo #f2cdcd;
    @define-color pink #f5c2e7;
    @define-color mauve #cba6f7;
    @define-color red #f38ba8;
    @define-color maroon #eba0ac;
    @define-color peach #fab387;
    @define-color yellow #f9e2af;
    @define-color green #a6e3a1;
    @define-color teal #94e2d5;
    @define-color sky #89dceb;
    @define-color sapphire #74c7ec;
    @define-color blue #89b4fa;
    @define-color lavender #b4befe;
    @define-color text #cdd6f4;
    @define-color subtext1 #bac2de;
    @define-color subtext0 #a6adc8;
    @define-color overlay2 #9399b2;
    @define-color overlay1 #7f849c;
    @define-color overlay0 #6c7086;
    @define-color surface2 #585b70;
    @define-color surface1 #45475a;
    @define-color surface0 #313244;
    @define-color base #1e1e2e;
    @define-color mantle #181825;
    @define-color crust #11111b;
      '';
    };
}
