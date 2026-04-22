#!/bin/bash
# QuickShell IPC manager — writes commands to /tmp/qs_widget_state
# which Main.qml watches via inotifywait.
#
# Usage:
#   qs_manager.sh toggle <widget> [arg]
#   qs_manager.sh open <widget> [arg]
#   qs_manager.sh close
#   qs_manager.sh <workspace_number>   (direct workspace switch)

cmd="$1"
widget="$2"
arg="$3"

case "$cmd" in
    toggle|open)
        if [ -n "$arg" ]; then
            echo "${cmd}:${widget}:${arg}" > /tmp/qs_widget_state
        else
            echo "${cmd}:${widget}" > /tmp/qs_widget_state
        fi
        ;;
    close)
        echo "close" > /tmp/qs_widget_state
        ;;
    [0-9]*)
        # Direct workspace switch
        hyprctl dispatch split:workspace "$cmd"
        ;;
    *)
        echo "Unknown command: $cmd" >&2
        exit 1
        ;;
esac
