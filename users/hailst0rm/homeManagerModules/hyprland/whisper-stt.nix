# Speech-to-Text using faster-whisper (via whisper-ctranslate2)
# Toggle recording with a keybind, transcription appears in active window
# Uses CTranslate2 for 4x faster inference with CUDA support
{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}: let
  cfg = config.services.whisperStt;
  hyprlandCfg = config.importConfig.hyprland;

  hasNvidia = osConfig.graphicDriver.nvidia.enable;

  # Device selection based on NVIDIA availability
  device =
    if hasNvidia
    then "cuda"
    else "cpu";

  # Compute type for optimal performance
  computeType =
    if hasNvidia
    then "float16"
    else "int8";

  # CUDA-enabled whisper-ctranslate2 when NVIDIA is available
  ctranslate2-cuda = pkgs.ctranslate2.override {
    withCUDA = true;
    withCuDNN = true;
  };

  whisper-ctranslate2-pkg =
    if hasNvidia
    then
      pkgs.whisper-ctranslate2.override {
        python3Packages = pkgs.python3Packages.overrideScope (_: pyprev: {
          ctranslate2 = pyprev.ctranslate2.override {
            ctranslate2-cpp = ctranslate2-cuda;
          };
        });
      }
    else pkgs.whisper-ctranslate2;

  # Main speech-to-text script
  whisperStt = pkgs.writeShellApplication {
    name = "whisper-stt";
    runtimeInputs = with pkgs; [
      whisper-ctranslate2-pkg
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
      VAD_FILTER="${
        if cfg.vadFilter
        then "true"
        else "false"
      }"
      VAD_MIN_SILENCE_MS="${toString cfg.vadMinSilenceMs}"
      VAD_THRESHOLD="${toString cfg.vadThreshold}"
      OUTPUT_MODE="${cfg.outputMode}"
      LOGFILE="/tmp/whisper-stt.log"

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
              --beam_size 1
              --temperature 0
              --condition_on_previous_text False
            )

            # Add language if specified
            if [[ -n "$LANGUAGE" ]]; then
              WHISPER_ARGS+=(--language "$LANGUAGE")
            fi

            # Enable Silero VAD: anchors sentence breaks at real pauses,
            # reduces dropped/merged words.
            if [[ "$VAD_FILTER" == "true" ]]; then
              WHISPER_ARGS+=(
                --vad_filter True
                --vad_threshold "$VAD_THRESHOLD"
                --vad_min_silence_duration_ms "$VAD_MIN_SILENCE_MS"
              )
            fi

            # Run faster-whisper transcription; log stderr for debugging
            # (device selection, CUDA fallback, etc.)
            whisper-ctranslate2 "''${WHISPER_ARGS[@]}" "$RECORDING_FILE" 2>>"$LOGFILE" || true

            # Read the transcription result
            OUTPUT_FILE="$OUTPUT_DIR/$(basename "$RECORDING_FILE" .wav).txt"
            if [[ -f "$OUTPUT_FILE" ]]; then
              # Join segment lines with a space (not "" — that glues "I\nreally" → "Ireally"),
              # then squeeze runs of whitespace and trim ends.
              RESULT=$(tr '\n' ' ' < "$OUTPUT_FILE" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')
            else
              RESULT=""
            fi

            # Clean up
            rm -f "$RECORDING_FILE"
            rm -rf "$OUTPUT_DIR"

            if [[ -n "$RESULT" ]]; then
              # Always copy to clipboard so manual paste works as a fallback.
              echo -n "$RESULT" | wl-copy

              if [[ "$OUTPUT_MODE" == "paste" ]]; then
                # Single Ctrl+Shift+V keystroke — no per-character race.
                wtype -M ctrl -M shift -k v -m shift -m ctrl
              else
                # Per-character typing with delay for non-terminal targets.
                wtype -d 20 "$RESULT"
              fi

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
      default = "large-v3-turbo";
      description = ''
        Whisper model to use. Uses faster-whisper (CTranslate2) for 4x speedup.
        Models ending in .en are English-only but faster.
        Distil models are English-only — do not pick them if multilingual
        auto-detection is wanted.
        Recommended: large-v3-turbo for multilingual with native punctuation.
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

    vadFilter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable Silero VAD chunking. Splits audio on real speech boundaries,
        giving Whisper natural segment breaks to anchor sentence endings
        and reducing dropped/merged words.
      '';
    };

    vadMinSilenceMs = lib.mkOption {
      type = lib.types.int;
      default = 700;
      description = ''
        Minimum silence (ms) that counts as a pause/segment break. Lower
        values (~500-700) map natural dictation pauses to sentence endings,
        helping Whisper insert periods. faster-whisper's default of 2000 ms
        is too long for typical dictation cadence.
      '';
    };

    vadThreshold = lib.mkOption {
      type = lib.types.float;
      default = 0.4;
      description = ''
        Silero VAD speech-probability threshold (0.0-1.0). Audio above this
        is considered speech. Silero's default of 0.5 frequently classifies
        brief quiet phonemes (the word "I", short "a") as silence, dropping
        them while leaving an inter-word space. Lower to 0.3-0.4 to keep
        them; raise toward 0.6 if background noise gets transcribed.
      '';
    };

    outputMode = lib.mkOption {
      type = lib.types.enum ["paste" "type"];
      default = "paste";
      description = ''
        How the transcript reaches the active window.
        - "paste": copy to clipboard and send Ctrl+Shift+V. Instant, avoids
          the kitty-keyboard-protocol race that turns capitals into CSI
          sequences (e.g. "C" -> "1;5u"). Works in foot, ghostty, kitty,
          alacritty, and other terminals using Ctrl+Shift+V for paste.
        - "type": emit characters one-by-one via wtype. Use for apps where
          Ctrl+Shift+V is not the paste binding (browsers, Electron).
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
      whisper-ctranslate2-pkg
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
