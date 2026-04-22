#!/usr/bin/env bash

# ============================================================================
# Workspace state daemon for QuickShell TopBar
# Outputs per-monitor workspace JSON for hyprsplit compatibility.
# Each monitor reads /tmp/qs_workspaces_<monitor_name>.json
# ============================================================================

# 1. ZOMBIE PREVENTION
for pid in $(pgrep -f "quickshell/workspaces.sh"); do
    if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
        kill -9 "$pid" 2>/dev/null
    fi
done

cleanup() {
    pkill -P $$ 2>/dev/null
}
trap cleanup EXIT SIGTERM SIGINT

# --- Special Cleanup for Network/Bluetooth ---
BT_PID_FILE="$HOME/.cache/bt_scan_pid"
if [ -f "$BT_PID_FILE" ]; then
    kill $(cat "$BT_PID_FILE") 2>/dev/null
    rm -f "$BT_PID_FILE"
fi
(timeout 2 bluetoothctl scan off > /dev/null 2>&1) &

# Configuration
SETTINGS_FILE="$HOME/.config/hypr/settings.json"
WS_PER_MON=$(jq -r '.workspaceCount // 5' "$SETTINGS_FILE" 2>/dev/null)
if ! [[ "$WS_PER_MON" =~ ^[0-9]+$ ]]; then
    WS_PER_MON=5
fi

print_workspaces() {
    local spaces active_id monitors

    spaces=$(timeout 2 hyprctl workspaces -j 2>/dev/null)
    monitors=$(timeout 2 hyprctl monitors -j 2>/dev/null)

    if [ -z "$spaces" ] || [ -z "$monitors" ]; then return; fi

    # For each monitor, output its workspace slice
    echo "$monitors" | jq -c '.[]' | while read -r mon; do
        local mon_name mon_id active_ws ws_start ws_end

        mon_name=$(echo "$mon" | jq -r '.name')
        mon_id=$(echo "$mon" | jq -r '.id')
        active_ws=$(echo "$mon" | jq -r '.activeWorkspace.id')

        # hyprsplit workspace ranges: monitor 0 → 1-N, monitor 1 → N+1-2N, etc.
        ws_start=$(( mon_id * WS_PER_MON + 1 ))
        ws_end=$(( (mon_id + 1) * WS_PER_MON ))

        echo "$spaces" | jq --unbuffered --argjson active "$active_ws" \
            --argjson ws_start "$ws_start" --argjson ws_end "$ws_end" \
            --argjson ws_per_mon "$WS_PER_MON" -c '
            (map( { (.id|tostring): . } ) | add) as $s
            |
            [range($ws_start; $ws_end + 1)] | to_entries | map(
                .value as $real_id |
                (.key + 1) as $display_id |

                (if $real_id == $active then "active"
                 elif ($s[$real_id|tostring] != null and $s[$real_id|tostring].windows > 0) then "occupied"
                 else "empty" end) as $state |

                (if $s[$real_id|tostring] != null then $s[$real_id|tostring].lastwindowtitle else "Empty" end) as $win |

                {
                    id: $display_id,
                    real_id: $real_id,
                    state: $state,
                    tooltip: $win
                }
            )
        ' > "/tmp/qs_workspaces_${mon_name}.tmp"

        mv "/tmp/qs_workspaces_${mon_name}.tmp" "/tmp/qs_workspaces_${mon_name}.json"
    done

    # Also write a combined file for backwards compatibility
    echo "$spaces" | jq --unbuffered --argjson a "$(echo "$monitors" | jq '[.[].activeWorkspace.id]')" \
        --arg end "$WS_PER_MON" -c '
        (map( { (.id|tostring): . } ) | add) as $s |
        [range(1; ($end|tonumber) + 1)] | map(
            . as $i |
            (if ($a | index($i)) then "active"
             elif ($s[$i|tostring] != null and $s[$i|tostring].windows > 0) then "occupied"
             else "empty" end) as $state |
            (if $s[$i|tostring] != null then $s[$i|tostring].lastwindowtitle else "Empty" end) as $win |
            { id: $i, state: $state, tooltip: $win }
        )
    ' > /tmp/qs_workspaces.tmp
    mv /tmp/qs_workspaces.tmp /tmp/qs_workspaces.json
}

# Print initial state
print_workspaces

# 2. THE EVENT DEBOUNCER
while true; do
    socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | while read -r line; do
        case "$line" in
            workspace*|focusedmon*|activewindow*|createwindow*|closewindow*|movewindow*|destroyworkspace*)
                while read -t 0.05 -r extra_line; do
                    continue
                done
                print_workspaces
                ;;
        esac
    done
    sleep 1
done
