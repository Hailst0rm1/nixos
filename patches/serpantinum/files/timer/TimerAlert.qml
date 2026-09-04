import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../reusables"
import "../"

// Centred modal shown when a countdown finishes. The notify-send tone stays a
// single ring; this is the part that waits until it is acknowledged.
PanelWindow {
    id: alertWindow

    WlrLayershell.namespace: "qs-timer-alert"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: alertWindow.isRinging ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property bool isRinging: false
    property string alertTitle: ""
    property string alertBody: ""

    visible: alertWindow.isRinging
    color: alertWindow.isRinging ? Qt.rgba(0, 0, 0, 0.45) : "transparent"

    function s(val) {
        return (typeof Scaler !== "undefined" && Scaler.s) ? Scaler.s(val) : val;
    }

    function dismiss() {
        alertWindow.isRinging = false;
    }

    Connections {
        target: TimerState
        function onFinished(title, body) {
            alertWindow.alertTitle = title;
            alertWindow.alertBody = body;
            alertWindow.isRinging = true;
        }
    }

    Shortcut {
        sequences: ["Escape", "Return", "Enter", "Space"]
        enabled: alertWindow.isRinging
        onActivated: alertWindow.dismiss()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: alertWindow.dismiss()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: alertWindow.s(420)
        implicitHeight: cardLayout.implicitHeight + (alertWindow.s(18) * 2)
        color: ThemeBackend.base
        radius: ThemeBackend.borderRadius
        border.color: ThemeBackend.surface0
        border.width: 1

        scale: alertWindow.isRinging ? 1.0 : 0.92
        Behavior on scale {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowVerticalOffset: alertWindow.s(4)
            shadowBlur: 0.5
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: alertWindow.s(18)
            spacing: alertWindow.s(14)

            RowLayout {
                Layout.fillWidth: true
                spacing: alertWindow.s(12)

                Rectangle {
                    Layout.preferredWidth: alertWindow.s(44)
                    Layout.preferredHeight: alertWindow.s(44)
                    Layout.alignment: Qt.AlignTop
                    radius: Math.max(0, ThemeBackend.borderRadius - 2)
                    color: ThemeBackend.surface0

                    Text {
                        anchors.centerIn: parent
                        text: "󰂚"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: alertWindow.s(22)
                        color: ThemeBackend.mauve
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: alertWindow.s(3)

                    Text {
                        text: alertWindow.alertTitle
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: alertWindow.s(14)
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    Text {
                        text: alertWindow.alertBody
                        color: ThemeBackend.subtext0
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: alertWindow.s(12)
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }

            ClickButton {
                Layout.fillWidth: true
                Layout.preferredHeight: alertWindow.s(34)
                cornerRadius: Math.max(0, ThemeBackend.borderRadius - 4)
                buttonText: "Dismiss"
                textFontSize: alertWindow.s(13)
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.base
                onClicked: alertWindow.dismiss()
            }
        }
    }
}
