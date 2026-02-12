# Speech-to-Text using faster-whisper (via whisper-ctranslate2)
# Toggle recording with a keybind, transcription appears in active window
# Uses CTranslate2 for 4x faster inference with CUDA support
{
  pkgs,
  lib,
  config,
  nvidiaEnabled,
  ...
}: let
  cfg = config.services.whisperStt;
  hyprlandCfg = config.importConfig.hyprland;

  # Device selection based on NVIDIA availability
  device =
    if nvidiaEnabled
    then "cuda"
    else "cpu";

  # Compute type for optimal performance
  computeType =
    if nvidiaEnabled
    then "float16"
    else "int8";

  # Main speech-to-text script
  whisperStt = pkgs.writeShellApplication {
    name = "whisper-stt";
    runtimeInputs = with pkgs; [
      whisper-ctranslate2
      pulseaudio # for parecord
      wl-clipboard
      wtype
      libnotify
      coreutils
      findutils
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Config
      MODEL="${cfg.model}"
      RECORDING_FILE="/tmp/whisper-recording-$$.wav"
      LOCKFILE="/tmp/whisper-stt.lock"
      OUTPUT_DIR="/tmp/whisper-output-$$"
      LANGUAGE="${
        if cfg.language != null
        then cfg.language
        else ""
      }"
      DEVICE="${device}"
      COMPUTE_TYPE="${computeType}"

      # Start recording
      start_recording() {
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

          # Find the most recent recording file
          RECORDING_FILE=$(find /tmp -maxdepth 1 -name 'whisper-recording-*.wav' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

          if [[ -n "$RECORDING_FILE" && -f "$RECORDING_FILE" ]]; then
            notify-send "Whisper STT" "Transcribing with $MODEL..." --urgency=low || true

            # Create output directory
            mkdir -p "$OUTPUT_DIR"

            # Build whisper command
            WHISPER_ARGS=(
              --model "$MODEL"
              --device "$DEVICE"
              --compute_type "$COMPUTE_TYPE"
              --output_dir "$OUTPUT_DIR"
              --output_format txt
              --verbose False
            )

            # Add language if specified
            if [[ -n "$LANGUAGE" ]]; then
              WHISPER_ARGS+=(--language "$LANGUAGE")
            fi

            # Run faster-whisper transcription
            whisper-ctranslate2 "''${WHISPER_ARGS[@]}" "$RECORDING_FILE" 2>/dev/null || true

            # Read the transcription result
            OUTPUT_FILE="$OUTPUT_DIR/$(basename "$RECORDING_FILE" .wav).txt"
            if [[ -f "$OUTPUT_FILE" ]]; then
              RESULT=$(cat "$OUTPUT_FILE" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            else
              RESULT=""
            fi

            # Clean up
            rm -f "$RECORDING_FILE"
            rm -rf "$OUTPUT_DIR"

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
        "turbo"
        "distil-large-v2"
        "distil-large-v3"
        "distil-medium.en"
        "distil-small.en"
      ];
      default = "small";
      description = ''
        Whisper model to use. Uses faster-whisper (CTranslate2) for 4x speedup.
        Models ending in .en are English-only but faster.
        Distil models are smaller/faster with similar accuracy.
        Recommended: small for multilingual, distil-large-v3 for speed+accuracy.
      '';
    };

    language = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "en";
      description = ''
        Language code for transcription (e.g., "en", "sv", "de").
        Leave null for auto-detection (works well with multilingual models).
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
      pkgs.whisper-ctranslate2
      whisperStt
      toggleWhisper
      pkgs.wtype
      pkgs.wl-clipboard
      pkgs.libnotify
    ];

    # Add keybinding to hyprland
    wayland.windowManager.hyprland.settings.bind = [
      "${cfg.keybind}, exec, ${toggleWhisper}/bin/toggle-whisper"
    ];
  };
}
