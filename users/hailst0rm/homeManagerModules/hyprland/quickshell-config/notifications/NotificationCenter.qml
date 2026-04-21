import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import "../"

Item {
    id: root

    // Passed from the popup loader in Main.qml
    property real uiScale: 1.0

    MatugenColors { id: _theme }

    Rectangle {
        anchors.fill: parent
        radius: 14 * root.uiScale
        color: _theme.base
        border.color: _theme.surface1
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12 * root.uiScale
            spacing: 10 * root.uiScale

            // Header row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * root.uiScale

                Text {
                    text: "Notifications"
                    font.family: "JetBrains Mono"
                    font.weight: Font.Bold
                    font.pixelSize: 18 * root.uiScale
                    color: _theme.text
                    Layout.fillWidth: true
                }

                Text {
                    text: notifList.count > 0 ? notifList.count + " items" : ""
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12 * root.uiScale
                    color: _theme.overlay1
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    width: clearLabel.implicitWidth + 20 * root.uiScale
                    height: clearLabel.implicitHeight + 10 * root.uiScale
                    radius: 8 * root.uiScale
                    color: clearMouse.containsMouse ? _theme.surface1 : _theme.surface0
                    visible: notifList.count > 0

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Clear All"
                        font.family: "JetBrains Mono"
                        font.weight: Font.Medium
                        font.pixelSize: 13 * root.uiScale
                        color: _theme.red
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Close all tracked notifications via the server model
                            for (let i = NotificationServer.trackedNotifications.values.length - 1; i >= 0; i--) {
                                let n = NotificationServer.trackedNotifications.values[i];
                                if (n && typeof n.close === "function") n.close();
                            }
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: _theme.surface1
            }

            // Empty state
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: notifList.count === 0

                Text {
                    anchors.centerIn: parent
                    text: "No notifications"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 14 * root.uiScale
                    color: _theme.overlay0
                }
            }

            // Scrollable notification list
            ListView {
                id: notifList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8 * root.uiScale
                model: NotificationServer.trackedNotifications

                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0.0; duration: 300; easing.type: Easing.OutQuint }
                        NumberAnimation { property: "x"; to: 60; duration: 300; easing.type: Easing.OutQuint }
                    }
                }

                displaced: Transition {
                    NumberAnimation { properties: "y"; duration: 300; easing.type: Easing.OutQuint }
                }

                delegate: Rectangle {
                    id: notifCard
                    width: ListView.view.width
                    height: notifCol.height + 16 * root.uiScale
                    radius: 10 * root.uiScale
                    color: notifMouse.containsMouse ? Qt.lighter(_theme.surface0, 1.1) : _theme.surface0
                    border.color: _theme.surface1
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: notifMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData && typeof modelData.invokeAction === "function") {
                                modelData.invokeAction("default");
                            }
                            if (modelData && typeof modelData.close === "function") {
                                modelData.close();
                            }
                        }
                    }

                    ColumnLayout {
                        id: notifCol
                        anchors.left: parent.left
                        anchors.right: dismissBtn.left
                        anchors.top: parent.top
                        anchors.margins: 8 * root.uiScale
                        spacing: 4 * root.uiScale

                        Text {
                            text: modelData.appName || "System"
                            font.family: "JetBrains Mono"
                            font.weight: Font.Medium
                            font.pixelSize: 11 * root.uiScale
                            color: _theme.overlay1
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.summary || ""
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: 14 * root.uiScale
                            color: _theme.text
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }

                        Text {
                            text: modelData.body || ""
                            font.family: "JetBrains Mono"
                            font.pixelSize: 12 * root.uiScale
                            color: _theme.subtext0
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            visible: (modelData.body || "") !== ""
                        }
                    }

                    // Dismiss button
                    Rectangle {
                        id: dismissBtn
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6 * root.uiScale
                        width: 22 * root.uiScale
                        height: 22 * root.uiScale
                        radius: width / 2
                        color: dismissMouse.containsMouse ? _theme.surface2 : "transparent"

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "\u00d7"
                            font.pixelSize: 16 * root.uiScale
                            color: _theme.overlay1
                        }

                        MouseArea {
                            id: dismissMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData && typeof modelData.close === "function") {
                                    modelData.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
