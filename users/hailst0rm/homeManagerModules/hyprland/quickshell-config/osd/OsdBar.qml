import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../"
import "../WindowRegistry.js" as Registry

PanelWindow {
    id: osdWindow

    property real uiScale: 1.0
    property real scale: Registry.getScale(screen.width, uiScale)

    function s(val) { return Registry.s(val, scale); }

    WlrLayershell.namespace: "qs-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    screen: Quickshell.cursorScreen

    anchors {
        bottom: true
        left: true
        right: true
    }

    margins.bottom: s(40)

    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"

    width: screen.width
    height: s(60)

    // --- State ---
    property string osdType: ""
    property real value: 0
    property bool muted: false
    property bool osdVisible: false

    MatugenColors { id: _theme }
    SystemConfig { id: sysConfig }

    // --- IPC Watcher ---
    Process {
        id: osdWatcher
        command: ["bash", "-c",
            "touch /tmp/qs_osd_state; " +
            "inotifywait -qq -e close_write /tmp/qs_osd_state 2>/dev/null; " +
            "cat /tmp/qs_osd_state"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim());
                    osdWindow.osdType = data.type || "";
                    osdWindow.value = data.value || 0;
                    osdWindow.muted = data.muted || false;
                    osdWindow.osdVisible = true;
                    hideTimer.restart();
                } catch (e) {
                    console.log("OSD parse error:", e);
                }
                osdWatcher.running = false;
                osdWatcher.running = true;
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osdWindow.osdVisible = false
    }

    function getIcon() {
        if (osdType === "brightness") return "󰃟";
        if (osdType === "mic") return muted ? "󰍭" : "󰍬";
        if (muted) return "󰝟";
        if (value >= 70) return "󰕾";
        if (value >= 30) return "󰖀";
        if (value > 0) return "󰕿";
        return "󰝟";
    }

    // --- Visual ---
    Item {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: osdWindow.s(300)
        height: osdWindow.s(46)

        opacity: osdWindow.osdVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutSine } }

        Rectangle {
            anchors.fill: parent
            radius: osdWindow.s(14)
            color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, 0.85)
            border.color: _theme.surface1
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: osdWindow.s(14)
                anchors.rightMargin: osdWindow.s(14)
                spacing: osdWindow.s(12)

                // Icon
                Text {
                    text: osdWindow.getIcon()
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: osdWindow.s(22)
                    color: sysConfig.accent
                    Layout.alignment: Qt.AlignVCenter
                }

                // Progress bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: osdWindow.s(6)
                    Layout.alignment: Qt.AlignVCenter
                    radius: osdWindow.s(3)
                    color: _theme.surface0

                    Rectangle {
                        width: parent.width * (osdWindow.muted ? 0 : osdWindow.value / 100)
                        height: parent.height
                        radius: parent.radius
                        color: sysConfig.accent

                        Behavior on width {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // Percentage
                Text {
                    text: Math.round(osdWindow.value) + "%"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: osdWindow.s(14)
                    font.weight: Font.Medium
                    color: _theme.text
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: osdWindow.s(42)
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
