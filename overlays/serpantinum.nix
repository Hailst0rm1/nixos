final: prev: {
  # patches/ carries structural edits, postPatch carries one-token swaps. Which
  # form a change belongs in, and how to build one: AGENTS.md "Editing upstream
  # source in an overlay". Why patching at all: docs/serpantinum-patch-architecture.md.
  serpantinum = prev.serpantinum.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        ../patches/serpantinum/0001-clickbutton-gradient.patch
        ../patches/serpantinum/0005-hyprsplit-workspaces.patch
        ../patches/serpantinum/0006-disable-wallpaper-engine.patch
        ../patches/serpantinum/0008-kb-extended-layout.patch
        ../patches/serpantinum/0009-timedate-center-white.patch
        ../patches/serpantinum/0011-weather-temp-no-decimal.patch
        ../patches/serpantinum/0016-nixos-logo-button.patch
        ../patches/serpantinum/0017-bat-pill-filled.patch
        ../patches/serpantinum/0018-pill-hover-scale.patch
        ../patches/serpantinum/0019-timedate-weather-hover-scale.patch
        ../patches/serpantinum/0020-center-group-hover.patch
        ../patches/serpantinum/0022-timer-alarm-panel.patch
        ../patches/serpantinum/0023-sysmon-panel-register.patch
        ../patches/serpantinum/0024-clipboard-localsend.patch
        ../patches/serpantinum/0025-timer-tab-navigation.patch
        ../patches/serpantinum/0026-workspace-dot-size.patch
        ../patches/serpantinum/0027-workspace-active-pill-height.patch
        ../patches/serpantinum/0027-escape-item-level-handlers.patch
        ../patches/serpantinum/0028-lock-wipe-gpu-shape.patch
      ];

    # Every --replace-fail target below occurs exactly once in its file.
    postPatch =
      (old.postPatch or "")
      + ''
        # Sources we author, copied in whole rather than carried as .patch
        # hunks. The rule in AGENTS.md is about edits to upstream's files: a
        # diff earns its keep there by breaking loudly when upstream moves the
        # code around it. A file upstream does not have has no such context, so
        # a patch would only be a worse way to store it. The two patches above
        # are the actual upstream edits — they wire these files in.
        install -Dm644 ${../patches/serpantinum/files/syspanel/SysMonPanel.qml} \
          src/quickshell/syspanel/SysMonPanel.qml
        install -Dm755 ${../patches/serpantinum/files/watchers/sysmon_fetcher.py} \
          src/quickshell/watchers/sysmon_fetcher.py
        install -Dm755 ${../patches/serpantinum/files/watchers/sysmon_privileged.sh} \
          src/quickshell/watchers/sysmon_privileged.sh
        install -Dm755 ${../patches/serpantinum/files/clipboard/localsend.py} \
          src/quickshell/clipboard/localsend.py

        # Temp pill: upstream's red reads as an alert at idle temperatures.
        substituteInPlace src/quickshell/bar/modules/system/SysMonWidget.qml \
          --replace-fail 'accentColor: ThemeBackend.red' 'accentColor: ThemeBackend.mauve'

        # Media play/pause hover: green is off-palette for this theme.
        substituteInPlace src/quickshell/bar/modules/MediaWidget.qml \
          --replace-fail 'ThemeBackend.green : ThemeBackend.text' 'ThemeBackend.mauve : ThemeBackend.text'
        substituteInPlace src/quickshell/bar/sidemodules/SideMediaWidget.qml \
          --replace-fail 'ThemeBackend.green : ThemeBackend.text' 'ThemeBackend.mauve : ThemeBackend.text'

        # Notification card: surface1 is a light grey that glares against the
        # rest of the palette; mantle sits a step below base.
        substituteInPlace src/quickshell/notifications/Notification.qml \
          --replace-fail 'typeRoot.readState === false ? Qt.lighter(ThemeBackend.surface1, 1.05) : ThemeBackend.surface1' \
                         'typeRoot.readState === false ? Qt.lighter(ThemeBackend.mantle, 1.35) : ThemeBackend.mantle'

        # Volume slider: upstream lightens sapphire by 1.5, which reads as blue
        # only because sapphire is a mid-tone. Our palette collapses the accent
        # roles onto one light green, so 1.5 washed the fill out to white while
        # brightness (1.1, from mauve) stayed green. Match the brightness factor.
        for f in src/quickshell/popouts/Osd.qml src/quickshell/syspanel/SystemPanel.qml
        do
          substituteInPlace "$f" \
            --replace-fail 'readonly property color volColor: Qt.lighter(ThemeBackend.sapphire, 1.5)' \
                           'readonly property color volColor: Qt.lighter(ThemeBackend.sapphire, 1.1)'
        done

        # Lock screen: 0.55 of blurMax left the screen grab legible at rest.
        substituteInPlace src/quickshell/lock/Lock.qml \
          --replace-fail 'blur: screenRoot.inputActive ? 1.0 : 0.55' \
                         'blur: screenRoot.inputActive ? 1.0 : 0.9'

        # Lock screen: the grim freeze shot only reached the blurred layer while
        # a password was being typed, so at rest the lock sat on the sharp
        # screenshot underneath and read as see-through. Showing it in the
        # blurred layer too makes the whole lock a blurred screen grab, the way
        # hyprlock's `path = screenshot; blur_passes = 2` did.
        substituteInPlace src/quickshell/lock/Lock.qml \
          --replace-fail 'opacity: (screenRoot.inputActive && status === Image.Ready && source.toString() !== "") ? 1.0 : 0.0' \
                         'opacity: (status === Image.Ready && source.toString() !== "") ? 1.0 : 0.0'

        # Occupied workspace dot: surface2 sits a hair above the empty dot's
        # surface0, so occupied and empty read as the same grey.
        substituteInPlace src/quickshell/bar/modules/WorkspacesWidget.qml \
          --replace-fail 'wsPill.isOccupied ? ThemeBackend.surface2' \
                         'wsPill.isOccupied ? ThemeBackend.overlay2'

        # Weather temperature: plain white, not peach.
        substituteInPlace src/quickshell/bar/modules/WeatherWidget.qml \
          --replace-fail 'color: ThemeBackend.peach' 'color: ThemeBackend.text'

        # Keyboard pill: 100px truncates layout names like "Colemak-SE".
        substituteInPlace src/quickshell/bar/modules/system/KbWidget.qml \
          --replace-fail 'maxWidth: barWindow.s(100)' 'maxWidth: barWindow.s(160)'

        # Breathing room between top bar blocks.
        substituteInPlace src/quickshell/bar/TopBar.qml \
          --replace-fail 'property real gap: barWindow ? barWindow.s(2) : 2' \
                         'property real gap: barWindow ? barWindow.s(10) : 10'

        # Battery glyph stays the filled icon; the percentage and the pill
        # colour already carry the level.
        substituteInPlace src/quickshell/bar/modules/system/BatWidget.qml \
          --replace-fail '(isCharging ? "󰂄" : (batCap > 20 ? "󰁹" : "󰂃"))' \
                         '(isCharging ? "󰂄" : "󰁹")'

        # Sysmon pills: drop the wave animation on the fill line.
        substituteInPlace src/quickshell/bar/modules/system/SysMonWidget.qml \
          --replace-fail 'property real waveAmp: (fillRatio < 0.99 && fillRatio > 0.01) ? (barWindow ? barWindow.s(3.5) : 3.5) * Math.sin(fillRatio * Math.PI) : 0' \
                         'property real waveAmp: 0'

        # Sysmon pills open the full System Monitor panel instead of the
        # quickactions usage tile — the panel is the larger view of the same
        # numbers. 0018 retargets the top-bar pills; this is the vertical-bar
        # copy of the same widget.
        substituteInPlace src/quickshell/bar/sidemodules/system/SideSysMonWidget.qml \
          --replace-fail '["quickshell", "-p", Caching.mainQml, "ipc", "call", "floating", "showSystemUsage"]' \
                         '["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle sysmon"]'

        # RAM glyph: upstream's \uF538 is Font Awesome 6 solid only, which Qt
        # never resolves here, so it rendered as tofu. This one is in the Nerd
        # Font and reads as a RAM stick rather than a second CPU chip.
        for f in \
          src/quickshell/bar/modules/system/SysMonWidget.qml \
          src/quickshell/bar/sidemodules/system/SideSysMonWidget.qml \
          src/quickshell/quickactions/actions/SystemUsage.qml \
          src/quickshell/lock/Lock.qml
        do
          substituteInPlace "$f" --replace-fail 'icon: "\uF538"' 'icon: ""'
        done
      '';

    # WelcomeTab.qml and AboutTab.qml both hardcode assets/logo.svg as the
    # guide's branding image — swap it for the NixOS logo rather than
    # patching two QML files to point elsewhere. Embedded as a base64 data
    # URI (not an external file:// xlink:href) since Qt's SVG image element
    # didn't render the external-reference form in practice.
    postInstall =
      (old.postInstall or "")
      + ''
        logoBase64=$(base64 -w0 ${../assets/images/nixos-logo.png})
        cat > "$out/share/serpantinum/assets/logo.svg" <<SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="512" height="512" viewBox="0 0 512 512">
          <image width="512" height="512" xlink:href="data:image/png;base64,$logoBase64"/>
        </svg>
        SVG
      '';

    # Upstream's pathDeps is a `let` binding inside nix/package.nix, so it can't
    # be extended through overrideAttrs — wrap the already-wrapped binaries a
    # second time instead (makeWrapper renames a colliding .foo-wrapped rather
    # than clobbering it, so double-wrapping is safe).
    #   pulseaudio    -> pactl. scripts/screenshot.sh lists it in REQUIRED_CMDS
    #                    and aborts with "Missing dependencies" without it;
    #                    upstream ships only libpulseaudio, the client library.
    #   xdg-user-dirs -> xdg-user-dir, used to resolve the screenshot save
    #                    directory (XDG PICTURES).
    postFixup =
      (old.postFixup or "")
      + ''
        for bin in serpantinum serpantinumd; do
          wrapProgram "$out/bin/$bin" \
            --prefix PATH : "${prev.lib.makeBinPath [prev.pulseaudio prev.xdg-user-dirs]}"
        done
      '';
  });
}
