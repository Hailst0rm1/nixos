import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"

// Slides up from the bottom edge while a YubiKey is flashing for a touch —
// sudo, ssh, a browser — so a prompt on another workspace isn't missed. State
// comes from yubikey-touch-detector's socket, which watches the key itself, so
// the toast follows the LED rather than any one program.
PanelWindow {
    id: toast

    WlrLayershell.namespace: "qs-yubikey-toast"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors.bottom: true
    color: "transparent"

    implicitWidth: pill.implicitWidth + s(32)
    implicitHeight: pill.implicitHeight + s(32)
    visible: toast.slide > 0.001
    // Clicks outside the pill fall through to whatever is underneath.
    mask: Region { item: pill }

    property bool waiting: false
    property real slide: waiting ? 1 : 0
    Behavior on slide { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    // Overlay-layer windows stack in the order they were shown, so a panel
    // opened while the toast is up (timer, launcher...) would cover it.
    // Re-showing in the same tick puts the toast back on top without a flicker.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (toast.visible && event.name === "openlayer" && event.data !== "qs-yubikey-toast") {
                toast.visible = false;
                toast.visible = Qt.binding(() => toast.slide > 0.001);
            }
        }
    }

    function s(val) {
        return (typeof Scaler !== "undefined" && Scaler.s) ? Scaler.s(val) : val;
    }

    Socket {
        id: detector
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/yubikey-touch-detector.socket"
        connected: true

        // Frames are 5 bytes ("U2F_1", "U2F_0", "GPG_1"...) with no delimiter,
        // and one read can carry several; the last U2F frame is the state.
        parser: SplitParser {
            splitMarker: ""
            onRead: (data) => {
                let i = data.lastIndexOf("U2F_");
                if (i < 0 || i + 4 >= data.length) return;
                toast.waiting = data[i + 4] === "1";
                if (toast.waiting) staleTimer.restart();
                else staleTimer.stop();
            }
        }

        onConnectionStateChanged: {
            if (!connected) reconnectTimer.start();
        }
    }

    Timer {
        id: reconnectTimer
        interval: 2000
        onTriggered: detector.connected = true
    }

    // The key gives up after ~30s and the detector reports it; this only
    // catches a missed U2F_0 so the toast can never stick.
    Timer {
        id: staleTimer
        interval: 35000
        onTriggered: toast.waiting = false
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        y: toast.height - height - toast.s(16) + (1 - toast.slide) * (height + toast.s(32))
        implicitWidth: row.implicitWidth + toast.s(26)
        implicitHeight: toast.s(34)
        radius: height / 2
        color: ThemeBackend.base
        border.width: Math.max(1, toast.s(1.5))
        border.color: Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.35 + 0.55 * pill.pulse)

        // One phase drives glyph, ring and border so they flash together,
        // roughly in step with the key's LED — same rhythm as the lock screen.
        property real pulse: 0
        SequentialAnimation on pulse {
            running: toast.visible
            loops: Animation.Infinite
            NumberAnimation { to: 1; duration: 450; easing.type: Easing.OutCubic }
            NumberAnimation { to: 0; duration: 650; easing.type: Easing.InCubic }
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: toast.s(8)

            Item {
                Layout.preferredWidth: toast.s(16)
                Layout.preferredHeight: toast.s(16)

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * (1 + 0.9 * pill.pulse)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: Math.max(1, toast.s(1.5))
                    border.color: ThemeBackend.mauve
                    opacity: 0.6 * (1 - pill.pulse)
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰌆"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: toast.s(14)
                    color: ThemeBackend.mauve
                    opacity: 0.45 + 0.55 * pill.pulse
                }
            }

            Text {
                text: "Please touch the FIDO authenticator."
                font.family: ThemeBackend.fontFamily
                font.pixelSize: toast.s(12)
                font.weight: Font.Bold
                color: ThemeBackend.text
            }
        }
    }
}
