#!/usr/bin/env bash
# Dispatcher for the SysMonPanel actions that need root.
#
# The real work lives in `serpantinum-sysmon-helper`, installed and validated by
# nixosModules/desktop/serpantinum-sysmon.nix, which also carries the polkit rule
# that lets a wheel user run it without a password prompt. Keeping the helper on
# the NixOS side rather than in this tree means the thing polkit grants rights to
# is a fixed store path the shell cannot substitute.
#
# Exits non-zero and says why when the module is not enabled, so the panel's
# notice line shows something honest instead of the action silently doing nothing.
set -euo pipefail

if ! helper=$(command -v serpantinum-sysmon-helper 2>/dev/null); then
    echo "serpantinum-sysmon-helper not installed (set serpantinum.sysmon.enable = true)" >&2
    exit 127
fi

exec pkexec "$helper" "$@"
