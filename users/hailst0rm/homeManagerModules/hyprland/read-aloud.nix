# Select-text-to-speech using Piper (neural TTS).
# Highlight text anywhere, press the keybind to hear it read aloud (en_GB-cori-high);
# press again to stop. Mirrors the toggle pattern in whisper-stt.nix.
{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.readAloud;
  hyprlandCfg = config.importConfig.hyprland;

  # rhasspy/piper-voices HEAD (HF publishes no release tags); bump rev + hashes to change/add voices.
  voiceRev = "b710b0ba0740da88dc36e1ab8fa6b310d43a3a48";
  voiceBase = "https://huggingface.co/rhasspy/piper-voices/resolve/${voiceRev}/en/en_GB/cori/high";
  voiceModel = pkgs.fetchurl {
    name = "en_GB-cori-high.onnx";
    url = "${voiceBase}/en_GB-cori-high.onnx";
    hash = "sha256-RwtN1jTJj4pIUNdib/w9/JB3Riju72YFpt2PiPMKWQM=";
  };
  voiceConfig = pkgs.fetchurl {
    name = "en_GB-cori-high.onnx.json";
    url = "${voiceBase}/en_GB-cori-high.onnx.json";
    hash = "sha256-nn+1tWcWEsIvPIHL5Gwa6HsDGkYyvLUJ5Jna1vHirew=";
  };

  # piper-tts 1.3.0 ignores -c and always reads "<model>.onnx.json" next to the model,
  # so the two fetched files must live in one dir with matching basenames.
  voiceDir = pkgs.runCommand "en_GB-cori-high-voice" {} ''
    mkdir -p "$out"
    ln -s ${voiceModel} "$out/en_GB-cori-high.onnx"
    ln -s ${voiceConfig} "$out/en_GB-cori-high.onnx.json"
  '';

  readAloud = pkgs.writeShellApplication {
    name = "read-aloud";
    runtimeInputs = with pkgs; [
      piper-tts
      pulseaudio # for paplay
      wl-clipboard
      libnotify
      coreutils
    ];
    text = ''
      LOCKFILE="$XDG_RUNTIME_DIR/read-aloud.lock"

      # Second press stops playback (kill the whole process group).
      if [[ -f "$LOCKFILE" ]]; then
        kill -- "-$(cat "$LOCKFILE")" 2>/dev/null || true
        rm -f "$LOCKFILE"
        exit 0
      fi

      if [[ -z "$(wl-paste --primary --no-newline 2>/dev/null | tr -d '[:space:]')" ]]; then
        notify-send "Read Aloud" "No text selected" --urgency=low || true
        exit 0
      fi

      notify-send "Read Aloud" "Reading… (press again to stop)" --urgency=low || true

      # setsid → new process group; $! (leader PID == PGID) is what we kill on toggle-off.
      # $1/$2 are expanded by the inner bash, not here — single quotes are intentional.
      # shellcheck disable=SC2016
      setsid bash -c '
        wl-paste --primary --no-newline \
          | piper -m "$1" --length-scale ${toString (1.0 / cfg.speed)} --output-raw -i /dev/stdin \
          | paplay --raw --rate=22050 --format=s16le --channels=1
        rm -f "$2"
      ' _ "${voiceDir}/en_GB-cori-high.onnx" "$LOCKFILE" &
      echo "$!" > "$LOCKFILE"
    '';
  };
in {
  options.services.readAloud = {
    enable = lib.mkEnableOption "select-text-to-speech (Piper) for Hyprland";

    keybind = lib.mkOption {
      type = lib.types.str;
      default = "$mainMod CTRL, R";
      description = "Hyprland keybind to read the primary selection aloud (toggle).";
    };

    speed = lib.mkOption {
      type = lib.types.float;
      default = 1.5;
      description = ''
        Playback speed multiplier (1.0 = normal, 1.5 = 50% faster).
        Maps to Piper --length-scale = 1/speed; pitch is preserved.
      '';
    };
  };

  config = lib.mkIf (hyprlandCfg.enable && cfg.enable) {
    home.packages = [readAloud];

    wayland.windowManager.hyprland.settings.bind = [
      "${cfg.keybind}, exec, ${readAloud}/bin/read-aloud"
    ];
  };
}
