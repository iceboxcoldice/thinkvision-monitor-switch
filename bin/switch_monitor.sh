#!/bin/bash
# ==============================================================================
# Monitor Input Switcher (Lenovo ThinkVision P32p-20 via m1ddc)
#
# Known Input Codes:
#   16 : USB-C
#   17 : HDMI
#   15 : DisplayPort (DP)
#
# Usage:
#   switch_monitor.sh             Toggle between USB-C (16) and HDMI (17)
#   switch_monitor.sh toggle      Toggle between USB-C (16) and HDMI (17)
#   switch_monitor.sh usbc        Switch to USB-C (16)
#   switch_monitor.sh hdmi        Switch to HDMI (17)
#   switch_monitor.sh dp          Switch to DisplayPort (15)
#   switch_monitor.sh status      Show current active input
#   switch_monitor.sh <num>       Set to any arbitrary VCP input code
# ==============================================================================
set -euo pipefail

M1DDC="/opt/homebrew/bin/m1ddc"
if [ ! -x "$M1DDC" ]; then
    M1DDC=$(command -v m1ddc 2>/dev/null || true)
fi

if [ -z "$M1DDC" ] || [ ! -x "$M1DDC" ]; then
    echo "Error: m1ddc utility not found. Please install with: brew install m1ddc" >&2
    exit 1
fi

# Input code mapping
input_name() {
    case "$1" in
        16) echo "USB-C (16)" ;;
        17) echo "HDMI (17)" ;;
        15) echo "DisplayPort (15)" ;;
        *)  echo "Input ($1)" ;;
    esac
}

get_current_input() {
    "$M1DDC" get input 2>/dev/null | tr -d '[:space:]'
}

set_input() {
    local target="$1"
    local current
    current=$(get_current_input)
    
    if [ -n "$current" ] && [ "$current" != "0" ] && [ "$current" = "$target" ]; then
        echo "Monitor is already on $(input_name "$target")."
        return 0
    fi

    echo "Switching monitor from $(input_name "$current") -> $(input_name "$target")..."
    "$M1DDC" set input "$target"
}

ACTION=$(echo "${1:-toggle}" | tr '[:upper:]' '[:lower:]')

case "$ACTION" in
    status|get|current)
        CURRENT=$(get_current_input)
        if [ -n "$CURRENT" ]; then
            echo "Current monitor input: $(input_name "$CURRENT")"
        else
            echo "Error: Could not read monitor input via DDC/CI." >&2
            exit 1
        fi
        ;;
    usbc|usb-c|typec|type-c|c|16)
        set_input 16
        ;;
    hdmi|h|17)
        set_input 17
        ;;
    dp|displayport|15)
        set_input 15
        ;;
    toggle|t|"")
        CURRENT=$(get_current_input)
        if [ "$CURRENT" = "16" ]; then
            set_input 17
        elif [ "$CURRENT" = "17" ]; then
            set_input 16
        else
            # Default fallback if on DP or unread: switch to USB-C
            echo "Current input is $(input_name "$CURRENT"). Toggling to USB-C (16)..."
            set_input 16
        fi
        ;;
    -h|--help)
        sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
            set_input "$ACTION"
        else
            echo "Unknown target or option: $ACTION" >&2
            echo "Valid options: toggle, usbc, hdmi, dp, status, or a numeric code (16, 17, 15)." >&2
            exit 1
        fi
        ;;
esac
