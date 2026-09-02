// System monitor panel: live CPU / RAM / GPU / ZRAM gauges over a process table.
//
// Registered as the "sysmon" widget in WindowRegistry.js, so it is opened with
// `serpantinum msg toggle sysmon` and follows the same show/hide lifecycle as
// every other master-window panel.
//
// Two data sources feed it. CPU, RAM and CPU temperature come from the existing
// SysData singleton (upstream's watchers/sys_fetcher.sh), subscribed only while
// this panel is visible. GPU, ZRAM and the process table come from
// watchers/sysmon_fetcher.py, polled here on the same 2s cadence — see that
// script for why the process scan reads /proc directly instead of shelling to ps.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

Item {
    id: window
    focus: true

    function s(val) {
        return Scaler.s(val);
    }

    // Same units and rounding quickactions/actions/SystemUsage.qml prints, so
    // the two views of the same SysData numbers agree.
    function formatBytes(bytes) {
        if (bytes <= 0 || isNaN(bytes)) return "0 B/s";
        let k = 1024, sizes = ["B/s", "K/s", "M/s", "G/s"];
        let i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i];
    }

    readonly property real boxRadius: Math.min(ThemeBackend.borderRadius, window.s(20))
    readonly property real cardRadius: Math.min(ThemeBackend.borderRadius, window.s(14))

    // Flips the lower list between "what is eating CPU" and "what is eating
    // VRAM". Driven by clicking the GPU card.
    property bool showingVram: false

    // Rows the user chose to hide, keyed by process name so a restart of the
    // same app stays hidden. Cleared when the panel is destroyed, deliberately:
    // hiding is a way to quieten the list while looking at something, not a
    // persistent preference worth a config file.
    property var hiddenNames: ({})

    property var gpuData: ({ present: false, vendor: "", pct: 0, temp: 0, memUsed: 0, memTotal: 0 })
    property var zramData: ({ present: false, mode: "swap", pct: 0, usedMb: 0, totalMb: 0, ratio: 0 })
    property int cachedMb: 0
    property string actionNotice: ""

    // Staggered entry, the same shape syspanel/SystemPanel.qml uses: the surface
    // fades in first, then each section lifts and scales into place behind it.
    // Every other master-window panel does this; without it this one snapped in.
    property real introContent: 0.0
    property real introTop: 0.0
    property real introCore: 0.0
    property real introList: 0.0

    function resetAndPlayIntro() {
        introContent = 0.0;
        introTop = 0.0;
        introCore = 0.0;
        introList = 0.0;
        startupSequence.restart();
    }

    ParallelAnimation {
        id: startupSequence
        NumberAnimation { target: window; property: "introContent"; to: 1.0; duration: 600; easing.type: Easing.OutQuart }

        SequentialAnimation {
            PauseAnimation { duration: 50 }
            NumberAnimation { target: window; property: "introTop"; from: 0; to: 1.0; duration: 900; easing.type: Easing.OutExpo }
        }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            NumberAnimation { target: window; property: "introCore"; from: 0; to: 1.0; duration: 900; easing.type: Easing.OutExpo }
        }
        SequentialAnimation {
            PauseAnimation { duration: 200 }
            NumberAnimation { target: window; property: "introList"; from: 0; to: 1.0; duration: 900; easing.type: Easing.OutExpo }
        }
    }

    // ---------------------------------------------------------------- data

    ListModel { id: procModel }

    Process {
        id: sysmonFetcher
        running: false
        command: ["python3", Caching.qsDir + "/watchers/sysmon_fetcher.py"]
        environment: ({ "QS_CACHE_SYSMON": Caching.getCacheDir("sysmon") })
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text ? this.text.trim() : "";
                if (!raw) return;
                let d;
                try {
                    d = JSON.parse(raw);
                } catch (e) {
                    return;
                }
                if (d.gpu) window.gpuData = d.gpu;
                if (d.zram) window.zramData = d.zram;
                window.cachedMb = d.cached || 0;
                window.syncProcs(window.showingVram ? (d.vram || []) : (d.procs || []));
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        running: false
        onTriggered: {
            // Restarting rather than relying on `running = true` matches how
            // SysData drives sys_fetcher.sh: the Process only re-runs on a
            // false->true edge.
            sysmonFetcher.running = false;
            sysmonFetcher.running = true;
        }
    }

    // Rewrites the model in place instead of clear()+append(), so rows keep
    // their delegates and the usage bars animate between polls rather than
    // flickering back from zero.
    function syncProcs(rows) {
        let filtered = [];
        for (let i = 0; i < rows.length; i++) {
            if (window.hiddenNames[rows[i].name]) continue;
            filtered.push(rows[i]);
            if (filtered.length >= 14) break;
        }

        for (let i = 0; i < filtered.length; i++) {
            let r = filtered[i];
            if (i < procModel.count) {
                let existing = procModel.get(i);
                if (existing.pid !== r.pid) procModel.set(i, r);
                else {
                    procModel.setProperty(i, "cpu", r.cpu);
                    procModel.setProperty(i, "rssMb", r.rssMb);
                }
            } else {
                procModel.append(r);
            }
        }
        while (procModel.count > filtered.length) {
            procModel.remove(procModel.count - 1);
        }
    }

    // --------------------------------------------------------------- actions

    Process { id: actionProc; running: false }

    function runAction(argv, notice) {
        actionProc.running = false;
        actionProc.command = argv;
        actionProc.running = true;
        window.actionNotice = notice;
        noticeTimer.restart();
    }

    Timer {
        id: noticeTimer
        interval: 2600
        repeat: false
        onTriggered: window.actionNotice = ""
    }

    function killPid(pid, name) {
        runAction(["kill", "-s", "TERM", String(pid)], "Sent TERM to " + name);
    }

    function renicePid(pid, name, value) {
        // Lowering priority (positive nice) any user may do. Raising it needs
        // privilege, so that path goes through the helper installed by
        // nixosModules/desktop/serpantinum-sysmon.nix; without it renice would
        // fail silently and the row would not change.
        if (value < 0) {
            runAction([Caching.qsDir + "/watchers/sysmon_privileged.sh",
                       "renice", String(value), String(pid)],
                      "Boosted " + name);
        } else {
            runAction(["renice", "-n", String(value), "-p", String(pid)],
                      (value === 0 ? "Reset " : "Lowered ") + name);
        }
    }

    function hideName(name) {
        let next = window.hiddenNames;
        next[name] = true;
        window.hiddenNames = next;
        for (let i = procModel.count - 1; i >= 0; i--) {
            if (procModel.get(i).name === name) procModel.remove(i);
        }
    }

    function cleanCache() {
        runAction([Caching.qsDir + "/watchers/sysmon_privileged.sh", "drop-caches"],
                  "Dropped page cache");
    }

    function cleanRam() {
        // Pushes idle anonymous pages out to swap (zram, where configured), which
        // is what frees "used" memory rather than cache. Needs privilege for the
        // same reason drop-caches does.
        runAction([Caching.qsDir + "/watchers/sysmon_privileged.sh", "compact-ram"],
                  "Reclaimed idle memory");
    }

    // -------------------------------------------------------------- lifecycle

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            resetAndPlayIntro();
            SysData.subscribe();
            sysmonFetcher.running = true;
            pollTimer.start();
        } else {
            startupSequence.stop();
            introContent = 0.0;
            introTop = 0.0;
            introCore = 0.0;
            introList = 0.0;
            pollTimer.stop();
            sysmonFetcher.running = false;
            SysData.unsubscribe();
        }
    }

    Component.onCompleted: {
        if (visible) resetAndPlayIntro();
    }

    Component.onDestruction: {
        if (pollTimer.running) {
            pollTimer.stop();
            SysData.unsubscribe();
        }
    }

    Keys.onEscapePressed: function (event) {
        contextMenu.visible = false;
        event.accepted = false; // let Main.qml's Escape shortcut close the panel
    }

    // ------------------------------------------------------------- usage card

    // The labels of a usage card: icon pill top-left, title top-right, sub-value
    // bottom-left, big value bottom-right. That is the layout
    // quickactions/actions/SystemUsage.qml gives its gauges, so a card here
    // reads as the same object seen larger.
    //
    // Drawn twice per card — once in normal colours, once in crust clipped to
    // the filled region — so the text stays legible as the level rises past it.
    component CardFace: Item {
        id: face

        property string icon: ""
        property string title: ""
        property string valueText: ""
        property string subText: ""

        property color iconBg: Qt.alpha(ThemeBackend.surface1, 0.6)
        property color iconFg: ThemeBackend.subtext0
        property color titleColor: ThemeBackend.subtext0
        property color subColor: ThemeBackend.subtext0
        property color valueColor: ThemeBackend.text

        IconButton {
            id: iconPill
            anchors.top: parent.top
            anchors.left: parent.left
            size: window.s(28)
            cornerRadius: window.s(14)
            accentColor: face.iconBg
            textColor: face.iconFg
            buttonIcon: face.icon
            iconFontSize: window.s(15)
            enabled: false
        }

        Text {
            anchors.verticalCenter: iconPill.verticalCenter
            anchors.right: parent.right
            text: face.title
            font.family: ThemeBackend.fontFamily
            font.pixelSize: window.s(13)
            font.weight: Font.DemiBold
            color: face.titleColor
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            // Both labels sit on the bottom row, so without this the sub-value
            // grows straight under the big one on a narrow card.
            anchors.right: valueLabel.left
            anchors.rightMargin: window.s(6)
            anchors.bottomMargin: window.s(2)
            text: face.subText
            font.family: ThemeBackend.fontFamily
            font.pixelSize: window.s(13)
            font.weight: Font.DemiBold
            color: face.subColor
            elide: Text.ElideRight
        }

        Text {
            id: valueLabel
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            text: face.valueText
            font.family: ThemeBackend.fontFamily
            font.pixelSize: window.s(24)
            font.weight: Font.Black
            color: face.valueColor
        }
    }

    // A gauge as a bottom-up liquid fill rather than a dial. Nothing else in the
    // shell draws a ring; the bar's SysMonWidget pills and the quickactions
    // squares both fill from the bottom under the same lighter->flat gradient,
    // so this matches them. The wave is left out for the same reason the overlay
    // takes it off the bar pills.
    component UsageCard: Item {
        id: card

        property real value: 0          // 0..100
        property string title: ""
        property string valueText: ""
        property string subText: ""
        property string icon: ""
        property color fillColor: ThemeBackend.mauve
        property bool clickable: false
        property bool selected: false

        signal clicked

        readonly property real pad: window.s(14)

        // Animating the drawn level rather than jumping to the new number is
        // what makes a 2s poll read as a live gauge.
        property real fillRatio: 0
        Behavior on fillRatio { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
        onValueChanged: fillRatio = Math.max(0, Math.min(1, value / 100))
        Component.onCompleted: fillRatio = Math.max(0, Math.min(1, value / 100))

        scale: (card.clickable && cardMouse.containsMouse) ? 1.02 : 1.0
        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }

        Rectangle {
            anchors.fill: parent
            radius: window.cardRadius
            color: Qt.darker(ThemeBackend.surface0, 1.04)
            border.width: 1
            border.color: card.selected ? Qt.alpha(card.fillColor, 0.85) : Qt.alpha(ThemeBackend.text, 0.06)
            Behavior on border.color { ColorAnimation { duration: 180 } }
        }

        // A rounded-rect clip path, not `clip: true`: Qt clips children to the
        // bounding box, which would square off the corners the fill reaches.
        Canvas {
            id: fillCanvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject

            onPaint: {
                let ctx = getContext("2d");
                let w = width;
                let h = height;
                let r = window.cardRadius;
                ctx.clearRect(0, 0, w, h);
                if (card.fillRatio <= 0.001 || w <= 0 || h <= 0) return;

                ctx.save();
                ctx.beginPath();
                ctx.moveTo(r, 0);
                ctx.lineTo(w - r, 0);
                ctx.quadraticCurveTo(w, 0, w, r);
                ctx.lineTo(w, h - r);
                ctx.quadraticCurveTo(w, h, w - r, h);
                ctx.lineTo(r, h);
                ctx.quadraticCurveTo(0, h, 0, h - r);
                ctx.lineTo(0, r);
                ctx.quadraticCurveTo(0, 0, r, 0);
                ctx.closePath();
                ctx.clip();

                let grad = ctx.createLinearGradient(0, 0, 0, h);
                grad.addColorStop(0, Qt.lighter(card.fillColor, 1.25).toString());
                grad.addColorStop(1, card.fillColor.toString());
                ctx.fillStyle = grad;
                ctx.globalAlpha = 0.92;
                ctx.fillRect(0, h * (1 - card.fillRatio), w, h * card.fillRatio);
                ctx.restore();
            }

            Connections {
                target: card
                function onFillRatioChanged() { fillCanvas.requestPaint(); }
                function onFillColorChanged() { fillCanvas.requestPaint(); }
            }
        }

        CardFace {
            anchors.fill: parent
            anchors.margins: card.pad
            icon: card.icon
            title: card.title
            valueText: card.valueText
            subText: card.subText
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * card.fillRatio
            clip: true
            visible: card.fillRatio > 0.01

            CardFace {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: card.pad
                anchors.rightMargin: card.pad
                anchors.bottomMargin: card.pad
                height: card.height - card.pad * 2

                icon: card.icon
                title: card.title
                valueText: card.valueText
                subText: card.subText

                iconBg: Qt.alpha(ThemeBackend.crust, 0.15)
                iconFg: ThemeBackend.crust
                titleColor: Qt.alpha(ThemeBackend.crust, 0.85)
                subColor: ThemeBackend.crust
                valueColor: ThemeBackend.crust
            }
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            enabled: card.clickable
            hoverEnabled: card.clickable
            cursorShape: card.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: card.clicked()
        }
    }

    // ------------------------------------------------------------------ chrome

    // Same surface treatment every other centred popup uses (NetworkPopup,
    // CalendarPopup): base fill, one-pixel surface0 border, theme radius.
    Rectangle {
        id: panel
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: ThemeBackend.base
        border.width: 1
        border.color: ThemeBackend.surface0
        clip: true
        opacity: window.introContent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: window.s(14)
            spacing: window.s(10)

            scale: 0.96 + (0.04 * window.introContent)

            // header ------------------------------------------------------
            RowLayout {
                id: headerRow
                Layout.fillWidth: true
                // A RowLayout nested in a ColumnLayout defaults fillHeight to
                // true, and the engine then shares the panel's spare height out
                // in proportion to each row's preferred height — which stretched
                // the gauges to ~640px and squeezed the process list to nothing.
                Layout.fillHeight: false
                Layout.preferredHeight: window.s(36)
                spacing: window.s(8)

                opacity: window.introTop
                transform: [
                    Translate { y: window.s(-20) * (1.0 - window.introTop) },
                    Scale {
                        origin.x: headerRow.width / 2
                        origin.y: headerRow.height / 2
                        xScale: 0.95 + (0.05 * window.introTop)
                        yScale: 0.95 + (0.05 * window.introTop)
                    }
                ]

                Text {
                    text: "System Monitor"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: window.s(15)
                    font.weight: Font.DemiBold
                    color: ThemeBackend.text
                }

                Text {
                    Layout.fillWidth: true
                    text: window.actionNotice
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: window.s(11)
                    color: ThemeBackend.overlay1
                    opacity: window.actionNotice !== "" ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                // Sized and padded like the clipboard panel's Clear button, the
                // other header action in the shell.
                ClickButton {
                    Layout.preferredWidth: window.s(124)
                    Layout.preferredHeight: window.s(36)
                    horizontalPadding: window.s(10)
                    cornerRadius: Math.min(ThemeBackend.borderRadius, window.s(10))
                    buttonText: "Clean Cache"
                    textFontSize: window.s(11)
                    buttonIcon: ""
                    iconFontSize: window.s(14)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    onTriggered: window.cleanCache()
                }

                ClickButton {
                    Layout.preferredWidth: window.s(116)
                    Layout.preferredHeight: window.s(36)
                    horizontalPadding: window.s(10)
                    cornerRadius: Math.min(ThemeBackend.borderRadius, window.s(10))
                    buttonText: "Clean RAM"
                    textFontSize: window.s(11)
                    buttonIcon: ""
                    iconFontSize: window.s(14)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    onTriggered: window.cleanRam()
                }
            }

            // usage cards -------------------------------------------------
            // Every accent role in this theme collapses to the one accent
            // colour, so the cards are told apart by icon and label, not by
            // hue — the same way the bar's sysmon pills are.
            RowLayout {
                id: usageRow
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: window.s(132)
                spacing: window.s(10)

                opacity: window.introCore
                transform: [
                    Translate { y: window.s(20) * (1.0 - window.introCore) },
                    Scale {
                        origin.x: usageRow.width / 2
                        origin.y: usageRow.height / 2
                        xScale: 0.95 + (0.05 * window.introCore)
                        yScale: 0.95 + (0.05 * window.introCore)
                    }
                ]

                UsageCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    value: SysData.cpu
                    title: "CPU"
                    valueText: SysData.cpu + "%"
                    subText: SysData.temp > 0 ? SysData.temp + "°C" : ""
                    icon: ""
                    fillColor: ThemeBackend.mauve
                }

                UsageCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    value: SysData.ramPercent
                    title: "MEMORY"
                    valueText: SysData.ramPercent + "%"
                    subText: SysData.ramGb > 0 ? SysData.ramGb.toFixed(1) + " GB" : ""
                    icon: ""
                    fillColor: ThemeBackend.blue
                }

                UsageCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    value: Math.max(0, Math.min(100, SysData.temp))
                    title: "TEMP"
                    valueText: SysData.temp + "\u00B0"
                    icon: "\uF2C9"
                    fillColor: ThemeBackend.mauve
                }

                UsageCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: window.gpuData.present
                    value: window.gpuData.pct
                    title: "GPU"
                    valueText: window.gpuData.pct + "%"
                    subText: window.gpuData.temp > 0 ? window.gpuData.temp + "°C" : ""
                    icon: ""
                    fillColor: ThemeBackend.teal
                    clickable: true
                    selected: window.showingVram
                    onClicked: {
                        window.showingVram = !window.showingVram;
                        // Repopulate straight away instead of waiting up to
                        // 2s for the next poll to swap the list over.
                        procModel.clear();
                        sysmonFetcher.running = false;
                        sysmonFetcher.running = true;
                    }
                }

                UsageCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    value: SysData.diskPercent
                    title: "DISK"
                    valueText: SysData.diskPercent + "%"
                    subText: SysData.diskTotalGb > 0
                             ? (SysData.diskGb.toFixed(0) + "/" + SysData.diskTotalGb.toFixed(0) + "G")
                             : ""
                    icon: "\uF0A0"
                    fillColor: ThemeBackend.blue
                }

                UsageCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: window.zramData.present
                    value: window.zramData.pct
                    // The fetcher falls back to reporting plain swap on a
                    // host with no zram device, and says so in `mode`.
                    title: window.zramData.mode === "zram" ? "ZRAM" : "SWAP"
                    valueText: window.zramData.pct + "%"
                    subText: Math.round(window.zramData.usedMb / 1024) + "/"
                             + Math.round(window.zramData.totalMb / 1024) + "G"
                    icon: ""
                    fillColor: ThemeBackend.sapphire
                }

                // Throughput has no ceiling to fill against, so this card stays
                // empty and carries the two speeds instead of one big number.
                UsageCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    value: 0
                    title: "NET"
                    subText: "\uF063 " + window.formatBytes(SysData.netRx) + "\n"
                             + "\uF062 " + window.formatBytes(SysData.netTx)
                    icon: "\uF0AC"
                    fillColor: ThemeBackend.teal
                }
            }

            // process list ------------------------------------------------
            // Boxed like the sections of the SystemPanel sidebar, rather than
            // sitting loose on the panel background.
            Rectangle {
                id: listBox
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: window.boxRadius
                color: Qt.darker(ThemeBackend.surface0, 1.04)

                opacity: window.introList
                transform: [
                    Translate { y: window.s(20) * (1.0 - window.introList) },
                    Scale {
                        origin.x: listBox.width / 2
                        origin.y: listBox.height / 2
                        xScale: 0.95 + (0.05 * window.introList)
                        yScale: 0.95 + (0.05 * window.introList)
                    }
                ]

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(12)
                    spacing: window.s(8)

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: window.showingVram ? "Top VRAM Consumers" : "Top Processes"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: window.s(13)
                            font.weight: Font.DemiBold
                            color: ThemeBackend.subtext0
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: Object.keys(window.hiddenNames).length > 0
                            text: "show hidden"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: window.s(11)
                            color: ThemeBackend.overlay1

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.hiddenNames = ({})
                            }
                        }
                    }

                    ListView {
                        id: procList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: procModel
                        spacing: window.s(2)
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: row
                            width: procList.width
                            height: window.s(32)
                            radius: Math.min(ThemeBackend.borderRadius, window.s(10))
                            color: rowMouse.containsMouse ? ThemeBackend.surface1 : "transparent"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            // Peak seen this session, so the bar is scaled against
                            // something stable rather than jumping every poll as the
                            // busiest process changes.
                            readonly property real barFrac: {
                                let top = procModel.count > 0 ? procModel.get(0).cpu : 0;
                                if (window.showingVram) {
                                    top = procModel.count > 0 ? procModel.get(0).rssMb : 0;
                                    return top > 0 ? Math.min(1, model.rssMb / top) : 0;
                                }
                                return top > 0 ? Math.min(1, model.cpu / top) : 0;
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function (mouse) {
                                    contextMenu.openFor(model.pid, model.name,
                                                        row.mapToItem(panel, mouse.x, mouse.y));
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: window.s(8)
                                anchors.rightMargin: window.s(8)
                                spacing: window.s(8)

                                // icon, with a letter badge when the desktop-entry
                                // lookup finds nothing (most daemons have no .desktop).
                                Item {
                                    Layout.preferredWidth: window.s(18)
                                    Layout.preferredHeight: window.s(18)

                                    readonly property string iconName: {
                                        if (typeof DesktopEntries === "undefined") return "";
                                        let entry = DesktopEntries.heuristicLookup(model.name);
                                        return entry ? (entry.icon || "") : "";
                                    }

                                    Image {
                                        id: procIcon
                                        anchors.fill: parent
                                        visible: status === Image.Ready && source !== ""
                                        source: {
                                            let ic = parent.iconName;
                                            if (!ic) return "";
                                            if (ic.startsWith("/")) return "file://" + ic;
                                            if (ic.startsWith("file://") || ic.startsWith("image://")) return ic;
                                            return "image://icon/" + ic;
                                        }
                                        sourceSize: Qt.size(36, 36)
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        smooth: true
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: !procIcon.visible
                                        radius: window.s(5)
                                        color: Qt.alpha(ThemeBackend.surface1, 0.8)

                                        Text {
                                            anchors.centerIn: parent
                                            text: (model.name || "?").charAt(0).toUpperCase()
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: window.s(9)
                                            font.weight: Font.DemiBold
                                            color: ThemeBackend.subtext0
                                        }
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: window.s(160)
                                    text: model.name
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: window.s(12)
                                    color: ThemeBackend.text
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: window.s(4)
                                    radius: height / 2
                                    color: Qt.alpha(ThemeBackend.surface2, 0.5)

                                    Rectangle {
                                        width: parent.width * row.barFrac
                                        height: parent.height
                                        radius: height / 2
                                        color: ThemeBackend.blue

                                        Behavior on width {
                                            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: window.s(140)
                                    horizontalAlignment: Text.AlignRight
                                    text: window.showingVram
                                          ? (model.rssMb + " MB VRAM")
                                          : (model.cpu.toFixed(1) + "%  ·  " + model.rssMb + " MB")
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: window.s(11)
                                    color: ThemeBackend.subtext0
                                }
                            }
                        }
                    }
                }
            }
        }

        // context menu ----------------------------------------------------
        // Drawn inside the panel rather than as a Qt Menu: a Menu would be its
        // own window, which a layer-shell surface cannot parent correctly.
        Rectangle {
            id: contextMenu
            visible: false
            z: 100
            width: window.s(160)
            height: menuCol.implicitHeight + window.s(12)
            radius: Math.min(ThemeBackend.borderRadius, window.s(16))
            color: ThemeBackend.mantle
            border.width: 1
            border.color: ThemeBackend.surface0

            property int targetPid: 0
            property string targetName: ""

            function openFor(pid, name, pt) {
                targetPid = pid;
                targetName = name;
                // Keep the menu inside the panel when the click lands near an edge.
                x = Math.min(pt.x, panel.width - width - window.s(6));
                y = Math.min(pt.y, panel.height - height - window.s(6));
                visible = true;
            }

            ColumnLayout {
                id: menuCol
                anchors.centerIn: parent
                width: parent.width - window.s(10)
                spacing: 0

                component MenuRow: Rectangle {
                    id: menuRow
                    property string label: ""
                    property color labelColor: ThemeBackend.text
                    signal picked

                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(28)
                    radius: Math.max(2, Math.min(ThemeBackend.borderRadius - 4, window.s(12)))
                    color: mrMouse.containsMouse ? ThemeBackend.surface0 : "transparent"

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: window.s(10)
                        text: menuRow.label
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: window.s(11)
                        color: menuRow.labelColor
                    }

                    MouseArea {
                        id: mrMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            menuRow.picked();
                            contextMenu.visible = false;
                        }
                    }
                }

                MenuRow {
                    label: "Kill"
                    labelColor: ThemeBackend.red
                    onPicked: window.killPid(contextMenu.targetPid, contextMenu.targetName)
                }

                MenuRow {
                    label: "Hide"
                    onPicked: window.hideName(contextMenu.targetName)
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: window.s(3)
                    Layout.bottomMargin: window.s(3)
                    color: Qt.alpha(ThemeBackend.surface1, 0.7)
                }

                MenuRow {
                    label: "Boost Priority"
                    onPicked: window.renicePid(contextMenu.targetPid, contextMenu.targetName, -5)
                }

                MenuRow {
                    label: "Lower Priority"
                    onPicked: window.renicePid(contextMenu.targetPid, contextMenu.targetName, 10)
                }

                MenuRow {
                    label: "Normal Priority"
                    onPicked: window.renicePid(contextMenu.targetPid, contextMenu.targetName, 0)
                }
            }
        }

        // Click-away closer, below the menu but above the list.
        MouseArea {
            anchors.fill: parent
            z: 99
            visible: contextMenu.visible
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: contextMenu.visible = false
        }
    }
}
