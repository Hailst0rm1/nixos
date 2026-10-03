# Select-text-to-speech using Piper (neural TTS).
# Highlight text anywhere, press the keybind to hear it read aloud (en_GB-cori-high, or sv_SE-nst-medium for Swedish text);
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
  # piper-tts 1.3.0 ignores -c and always reads "<model>.onnx.json" next to the model,
  # so the two fetched files must live in one dir with matching basenames.
  # Returns the path to the .onnx model.
  mkVoice = {
    name,
    path,
    modelHash,
    configHash,
  }: let
    fetch = file: hash:
      pkgs.fetchurl {
        name = file;
        url = "https://huggingface.co/rhasspy/piper-voices/resolve/${voiceRev}/${path}/${file}";
        inherit hash;
      };
    dir = pkgs.runCommand "${name}-voice" {} ''
      mkdir -p "$out"
      ln -s ${fetch "${name}.onnx" modelHash} "$out/${name}.onnx"
      ln -s ${fetch "${name}.onnx.json" configHash} "$out/${name}.onnx.json"
    '';
  in "${dir}/${name}.onnx";

  # Both voices are 22050 Hz, matching the paplay --rate below.
  voiceEn = mkVoice {
    name = "en_GB-cori-high";
    path = "en/en_GB/cori/high";
    modelHash = "sha256-RwtN1jTJj4pIUNdib/w9/JB3Riju72YFpt2PiPMKWQM=";
    configHash = "sha256-nn+1tWcWEsIvPIHL5Gwa6HsDGkYyvLUJ5Jna1vHirew=";
  };
  voiceSv = mkVoice {
    name = "sv_SE-nst-medium";
    path = "sv/sv_SE/nst/medium";
    modelHash = "sha256-3wEfVoJaWd0e/AgMOKZaHvcEB+YPYwUOkkb0Oj1+Rx4=";
    configHash = "sha256-1F3XTLtOylhpS/BKl+JDBECSR28opVriZCTwZTCGmAo=";
  };

  readAloud = pkgs.writeShellApplication {
    name = "read-aloud";
    runtimeInputs = with pkgs; [
      piper-tts
      pulseaudio # for paplay
      wl-clipboard
      libnotify
      coreutils
      gnugrep
    ];
    text = ''
      LOCKFILE="$XDG_RUNTIME_DIR/read-aloud.lock"

      # Second press stops playback (kill the whole process group).
      if [[ -f "$LOCKFILE" ]]; then
        kill -- "-$(cat "$LOCKFILE")" 2>/dev/null || true
        rm -f "$LOCKFILE"
        exit 0
      fi

      TEXT="$(wl-paste --primary --no-newline 2>/dev/null || true)"
      if [[ -z "''${TEXT//[[:space:]]/}" ]]; then
        notify-send "Read Aloud" "No text selected" --urgency=low || true
        exit 0
      fi

      # ponytail: åäö/stopword heuristic picks one voice for the whole selection;
      # swap in a real language detector if it misfires or mixed-language text matters.
      VOICE="${voiceEn}"
      if grep -qiE '[åäö]|\b(och|att|det|inte|jag|som|med|har)\b' <<<"$TEXT"; then
        VOICE="${voiceSv}"
      fi

      notify-send "Read Aloud" "Reading… (press again to stop)" --urgency=low || true

      # setsid → new process group; $! (leader PID == PGID) is what we kill on toggle-off.
      # $1/$2/$3 are expanded by the inner bash, not here — single quotes are intentional.
      # shellcheck disable=SC2016
      setsid bash -c '
        printf "%s" "$3" \
          | piper -m "$1" --length-scale ${toString (1.0 / cfg.speed)} --output-raw -i /dev/stdin \
          | paplay --raw --rate=22050 --format=s16le --channels=1
        rm -f "$2"
      ' _ "$VOICE" "$LOCKFILE" "$TEXT" &
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
