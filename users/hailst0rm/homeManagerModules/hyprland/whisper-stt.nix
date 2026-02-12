# Speech-to-Text using whisper-cpp (hyprflow-style approach)
# Toggle recording with a keybind, transcription appears in active window
{
  pkgs,
  pkgs-unstable,
  lib,
  config,
  ...
}: let
  cfg = config.services.whisperStt;
  hyprlandCfg = config.importConfig.hyprland;

  # Model path - downloaded on first use
  modelDir = "$HOME/.local/share/whisper-models";
  modelFile = "${modelDir}/ggml-${cfg.model}.bin";

  # Main speech-to-text script (hyprflow-style)
  whisperStt = pkgs.writeShellApplication {
    name = "whisper-stt";
    runtimeInputs = with pkgs; [
      whisper-cpp
      pulseaudio # for parecord
      wl-clipboard
      wtype
      libnotify
      curl
      coreutils
      findutils
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Config
      MODEL_DIR="${modelDir}"
      MODEL="${cfg.model}"
      MODEL_FILE="$MODEL_DIR/ggml-$MODEL.bin"
      RECORDING_FILE="/tmp/whisper-recording-$$.wav"
      LOCKFILE="/tmp/whisper-stt.lock"
      LANGUAGE="${
        if cfg.language != null
        then cfg.language
        else ""
      }"

      # Ensure model directory exists
      mkdir -p "$MODEL_DIR"

      # Download model if not present
      download_model() {
        if [[ ! -f "$MODEL_FILE" ]]; then
          notify-send "Whisper STT" "Downloading model: $MODEL" --urgency=low || true
          MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$MODEL.bin"
          curl -L "$MODEL_URL" -o "$MODEL_FILE" || {
            notify-send "Whisper STT" "Failed to download model!" --urgency=critical
            exit 1
          }
          notify-send "Whisper STT" "Model downloaded successfully" --urgency=low || true
        fi
      }

      # Start recording
      start_recording() {
        download_model

        # Create lock file with PID
        echo $$ > "$LOCKFILE"

        notify-send "Whisper STT" "Recording... (press again to stop)" --urgency=low || true

        # Record audio using PulseAudio
        parecord --channels=1 --rate=16000 --format=s16le --file-format=wav "$RECORDING_FILE" &
        RECORD_PID=$!
        echo "$RECORD_PID" >> "$LOCKFILE"

        # Wait for stop signal
        wait "$RECORD_PID" 2>/dev/null || true
      }

      # Stop recording and transcribe
      stop_recording() {
        if [[ -f "$LOCKFILE" ]]; then
          # Read PIDs from lock file
          PIDS=$(cat "$LOCKFILE")
          for PID in $PIDS; do
            kill "$PID" 2>/dev/null || true
          done
          rm -f "$LOCKFILE"

          # Wait a moment for the recording to finalize
          sleep 0.3

          # Find the most recent recording file using find instead of ls
          RECORDING_FILE=$(find /tmp -maxdepth 1 -name 'whisper-recording-*.wav' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

          if [[ -n "$RECORDING_FILE" && -f "$RECORDING_FILE" ]]; then
            notify-send "Whisper STT" "Transcribing..." --urgency=low || true

            # Run whisper-cli and extract text (with optional language flag)
            if [[ -n "$LANGUAGE" ]]; then
              RESULT=$(whisper-cli -m "$MODEL_FILE" -f "$RECORDING_FILE" -l "$LANGUAGE" -nt 2>/dev/null | grep -v "^\[" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            else
              RESULT=$(whisper-cli -m "$MODEL_FILE" -f "$RECORDING_FILE" -nt 2>/dev/null | grep -v "^\[" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            fi

            # Clean up recording
            rm -f "$RECORDING_FILE"

            if [[ -n "$RESULT" ]]; then
              # Copy to clipboard
              echo -n "$RESULT" | wl-copy

              # Type the text into the active window
              wtype "$RESULT"

              notify-send "Whisper STT" "Transcribed: ''${RESULT:0:50}..." --urgency=low || true
            else
              notify-send "Whisper STT" "No speech detected" --urgency=low || true
            fi
          fi
        fi
      }

      # Toggle recording
      if [[ -f "$LOCKFILE" ]]; then
        stop_recording
      else
        start_recording
      fi
    '';
  };

  # Toggle script with visual feedback
  toggleWhisper = pkgs.writeShellApplication {
    name = "toggle-whisper";
    runtimeInputs = [whisperStt];
    text = ''
      whisper-stt
    '';
  };
in {
  options.services.whisperStt = {
    enable = lib.mkEnableOption "Enable Whisper speech-to-text for Hyprland.";

    model = lib.mkOption {
      type = lib.types.enum [
        "tiny"
        "tiny.en"
        "base"
        "base.en"
        "small"
        "small.en"
        "medium"
        "medium.en"
        "large-v1"
        "large-v2"
        "large-v3"
        "large-v3-turbo"
      ];
      default = "base.en";
      description = ''
        Whisper model to use. Larger models are more accurate but slower.
        Models ending in .en are English-only but faster.
        Recommended: base.en for speed, medium for accuracy.
      '';
    };

    language = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "en";
      description = ''
        Language code for transcription (e.g., "en", "de", "es").
        Leave null for auto-detection.
      '';
    };

    keybind = lib.mkOption {
      type = lib.types.str;
      default = "$mainMod SHIFT, S";
      description = ''
        Hyprland keybind to toggle recording.
        Uses Hyprland bind format (e.g., "$mainMod SHIFT, S" or "SUPER, F12").
      '';
    };
  };

  config = lib.mkIf (hyprlandCfg.enable && cfg.enable) {
    # Add required packages
    home.packages = [
      pkgs.whisper-cpp
      whisperStt
      toggleWhisper
      pkgs.wtype
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.curl
    ];

    # Add keybinding to hyprland
    wayland.windowManager.hyprland.settings.bind = [
      "${cfg.keybind}, exec, ${toggleWhisper}/bin/toggle-whisper"
    ];
  };
}
