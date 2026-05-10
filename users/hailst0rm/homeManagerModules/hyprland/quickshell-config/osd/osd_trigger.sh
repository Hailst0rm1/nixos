#!/usr/bin/env bash
# OSD trigger — reads current state and writes JSON to /tmp/qs_osd_state
# Usage: osd_trigger.sh volume|brightness|mic

TYPE="$1"
OSD_FILE="/tmp/qs_osd_state"

case "$TYPE" in
  volume)
    RAW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    VOL=$(echo "$RAW" | awk '{print int($2*100)}')
    if echo "$RAW" | grep -q MUTED; then MUTED=true; else MUTED=false; fi
    printf '{"type":"volume","value":%d,"muted":%s}\n' "${VOL:-0}" "$MUTED" > "$OSD_FILE"
    ;;
  brightness)
    BRI=$(brightnessctl -m 2>/dev/null | awk -F, '{gsub(/%/,"",$4); print int($4)}')
    printf '{"type":"brightness","value":%d,"muted":false}\n' "${BRI:-0}" > "$OSD_FILE"
    ;;
  mic)
    RAW=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)
    VOL=$(echo "$RAW" | awk '{print int($2*100)}')
    if echo "$RAW" | grep -q MUTED; then MUTED=true; else MUTED=false; fi
    printf '{"type":"mic","value":%d,"muted":%s}\n' "${VOL:-0}" "$MUTED" > "$OSD_FILE"
    ;;
esac
