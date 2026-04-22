import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root
    focus: true

    // --- Responsive Scaling Logic ---
    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    
    function s(val) { 
        return scaler.s(val); 
    }

    // -------------------------------------------------------------------------
    // KEYBOARD SHORTCUTS
    // -------------------------------------------------------------------------
    Keys.onEscapePressed: {
        closeSequence.start();
        event.accepted = true;
    }
    Keys.onReturnPressed: {
        root.saveAppSettings();
        event.accepted = true;
    }
    Keys.onEnterPressed: {
        root.saveAppSettings();
        event.accepted = true;
    }

    MatugenColors { id: _theme }
    // -------------------------------------------------------------------------
    // COLORS
    // -------------------------------------------------------------------------
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color subtext1: _theme.subtext1
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color overlay0: _theme.overlay0
    readonly property color mauve: _theme.mauve
    readonly property color pink: _theme.pink
    readonly property color blue: _theme.blue
    readonly property color sapphire: _theme.sapphire
    readonly property color green: _theme.green
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow
    readonly property color red: _theme.red

    // -------------------------------------------------------------------------
    // SSOT GLOBAL SETTINGS & UPDATES
    // -------------------------------------------------------------------------
    property int initialWorkspaceCount: 8 // Track the value loaded from JSON
    
    property real setUiScale: 1.0
    property bool setOpenGuideAtStartup: true
    property bool setTopbarHelpIcon: true
    property int setWorkspaceCount: 8
    property string setWallpaperDir: {
        const dir = Quickshell.env("WALLPAPER_DIR")
        return (dir && dir !== "") 
        ? dir 
        : Quickshell.env("HOME") + "/Pictures/Wallpapers"
    }
    property string setLanguage: ""
    property string setKbOptions: "grp:alt_shift_toggle"

    property var kbToggleModelArr: [
        { label: "Alt + Shift", val: "grp:alt_shift_toggle" },
        { label: "Win + Space", val: "grp:win_space_toggle" },
        { label: "Caps Lock", val: "grp:caps_toggle" },
        { label: "Ctrl + Shift", val: "grp:ctrl_shift_toggle" },
        { label: "Ctrl + Alt", val: "grp:ctrl_alt_toggle" },
        { label: "Right Alt", val: "grp:toggle" },
        { label: "No Toggle", val: "" }
    ]

    function getKbToggleLabel(val) {
        for (let i = 0; i < root.kbToggleModelArr.length; i++) {
            if (root.kbToggleModelArr[i].val === val) return root.kbToggleModelArr[i].label;
        }
        return "Alt + Shift";
    }

    function saveAppSettings() {
        let config = {
            "uiScale": root.setUiScale,
            "openGuideAtStartup": root.setOpenGuideAtStartup,
            "topbarHelpIcon": root.setTopbarHelpIcon,
            "wallpaperDir": root.setWallpaperDir,
            "language": root.setLanguage,
            "kbOptions": root.setKbOptions,
            "workspaceCount": root.setWorkspaceCount
        };
        let jsonString = JSON.stringify(config, null, 2);
        
        let cmd = "mkdir -p ~/.config/hypr/ && echo '" + jsonString + "' > ~/.config/hypr/settings.json && notify-send 'Quickshell' 'Settings Applied Successfully!'";
                  
        Quickshell.execDetached(["bash", "-c", cmd]);
        
        // ONLY queue a TopBar reload if the workspace count actually changed
        if (root.setWorkspaceCount !== root.initialWorkspaceCount) {
            Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/quickshell/TopBar.qml", "ipc", "call", "topbar", "queueReload"]);
            
            // Update the baseline so subsequent saves don't trigger unnecessary reloads
            root.initialWorkspaceCount = root.setWorkspaceCount; 
        }
    }
    Process {
        id: hyprLangReader
        command: ["bash", "-c", "grep -m1 '^ *kb_layout *=' ~/.config/hypr/hyprland.conf | cut -d'=' -f2 | tr -d ' '"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text ? this.text.trim() : "";
                if (out.length > 0 && root.setLanguage === "") {
                    root.setLanguage = out;
                }
            }
        }
    }

    Process {
        id: settingsReader
        command: ["bash", "-c", "cat ~/.config/hypr/settings.json 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0 && this.text.trim() !== "{}") {
                        let parsed = JSON.parse(this.text);
                        if (parsed.uiScale !== undefined) root.setUiScale = parsed.uiScale;
                        if (parsed.openGuideAtStartup !== undefined) root.setOpenGuideAtStartup = parsed.openGuideAtStartup;
                        if (parsed.topbarHelpIcon !== undefined) root.setTopbarHelpIcon = parsed.topbarHelpIcon;
                        if (parsed.wallpaperDir !== undefined) root.setWallpaperDir = parsed.wallpaperDir;
                        if (parsed.language !== undefined && parsed.language !== "") root.setLanguage = parsed.language;
                        if (parsed.kbOptions !== undefined) root.setKbOptions = parsed.kbOptions;
                        if (parsed.workspaceCount !== undefined) {
                            root.setWorkspaceCount = parsed.workspaceCount;
                            root.initialWorkspaceCount = parsed.workspaceCount; // TRACK BASELINE
                        }
                    } else {
                        root.saveAppSettings();
                    }
                } catch (e) {
                    console.log("Error parsing global settings:", e);
                }
            }
        }
    }
    ListModel {
        id: langModel
        ListElement { code: "us"; name: "English (US)" }
        ListElement { code: "gb"; name: "English (UK)" }
        ListElement { code: "au"; name: "English (Australia)" }
        ListElement { code: "ca"; name: "English/French (Canada)" }
        ListElement { code: "ie"; name: "English (Ireland)" }
        ListElement { code: "nz"; name: "English (New Zealand)" }
        ListElement { code: "za"; name: "English (South Africa)" }
        ListElement { code: "fr"; name: "French" }
        ListElement { code: "de"; name: "German" }
        ListElement { code: "es"; name: "Spanish" }
        ListElement { code: "pt"; name: "Portuguese" }
        ListElement { code: "it"; name: "Italian" }
        ListElement { code: "se"; name: "Swedish" }
        ListElement { code: "no"; name: "Norwegian" }
        ListElement { code: "dk"; name: "Danish" }
        ListElement { code: "fi"; name: "Finnish" }
        ListElement { code: "pl"; name: "Polish" }
        ListElement { code: "ru"; name: "Russian" }
        ListElement { code: "ua"; name: "Ukrainian" }
        ListElement { code: "cn"; name: "Chinese" }
        ListElement { code: "jp"; name: "Japanese" }
        ListElement { code: "kr"; name: "Korean" }
    }

    ListModel { id: pathSuggestModel }
    ListModel { id: langSearchModel }

    function updateLangSearch(query) {
        langSearchModel.clear();
        let q = query.trim().toLowerCase();
        if (q === "") return;
        for (let i = 0; i < langModel.count; i++) {
            let item = langModel.get(i);
            if (item.code.toLowerCase().includes(q) || item.name.toLowerCase().includes(q)) {
                langSearchModel.append({ code: item.code, name: item.name });
            }
        }
    }

    Process {
        id: pathSuggestProc
        property string query: ""
        command: ["bash", "-c", "eval ls -dp " + query + "* 2>/dev/null | grep '/$' | head -n 5 || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                pathSuggestModel.clear();
                if (this.text) {
                    let lines = this.text.trim().split('\n');
                    for (let i = 0; i < lines.length; i++) {
                        if (lines[i].length > 0) {
                            pathSuggestModel.append({ path: lines[i] });
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // ANIMATIONS
    // -------------------------------------------------------------------------
    property real introContent: 0.0

    Component.onCompleted: { 
        startupSequence.start(); 
    }

    SequentialAnimation {
        id: startupSequence
        PauseAnimation { duration: 100 }
        NumberAnimation { 
            target: root
            property: "introContent"
            from: 0.0
            to: 1.0
            duration: 700
            easing.type: Easing.OutBack
            easing.overshoot: 1.05
        } 
    }

    SequentialAnimation {
        id: closeSequence
        NumberAnimation { 
            target: root
            property: "introContent"
            to: 0.0
            duration: 250
            easing.type: Easing.InExpo 
        }
        ScriptAction { 
            script: {
                if (root.requiresReload) {
                    // Wait for qs_manager.sh to clear the active widget state to prevent TopBar layout jumping
                    let script = Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh close; " +
                                 "while [ -n \"$(cat /tmp/qs_current_widget 2>/dev/null)\" ]; do sleep 0.1; done; " +
                                 "sleep 0.2; " + 
                                 "qs -p ~/.config/quickshell/TopBar.qml ipc call topbar forceReload";
                    Quickshell.execDetached(["bash", "-c", script]);
                } else {
                    Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
                }
            } 
        }
    }

    // -------------------------------------------------------------------------
    // SIDEBAR BACKGROUND
    // -------------------------------------------------------------------------
    Rectangle {
        id: sidebarPanel
        anchors.fill: parent
        color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.95)
        radius: root.s(16)
        border.width: 1
        border.color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.8)
        clip: true

        // --- Straighten Left Corners ---
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.s(16)
            color: sidebarPanel.color

            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: sidebarPanel.border.color }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: sidebarPanel.border.color }
            Rectangle { anchors.left: parent.left; width: 1; height: parent.height; color: sidebarPanel.border.color }
        }

        // -------------------------------------------------------------------------
        // FLICKABLE CONTENT AREA
        // -------------------------------------------------------------------------
        Item {
            anchors.fill: parent
            opacity: introContent
            scale: 0.98 + (0.02 * introContent)

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: settingsMainCol.implicitHeight + root.s(100)
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: settingsMainCol
                    width: parent.width - root.s(48)
                    x: root.s(24)
                    y: root.s(24)
                    spacing: root.s(20)

                    // --- HEADER ---
                    RowLayout {
                        Layout.fillWidth: true
                        Text { 
                            text: "Settings"
                            font.family: "Iosevka Nerd Font"
                            font.weight: Font.Black
                            font.pixelSize: root.s(26)
                            color: root.text
                            Layout.alignment: Qt.AlignVCenter 
                        }
                    }

                    // --- SETTINGS LIST ---
                    
                    // Box 1: Startup & Icons
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: col1.implicitHeight + root.s(32)
                        radius: root.s(12)
                        color: Qt.alpha(root.surface0, 0.5)
                        border.color: root.surface1
                        border.width: 1
                        
                        ColumnLayout {
                            id: col1
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: root.s(16)
                            spacing: root.s(16)
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: root.s(16)
                                Item {
                                    Layout.preferredWidth: root.s(24)
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: root.s(2)
                                    Text { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20); color: root.peach }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: root.s(4)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Guide on startup"; font.family: "Iosevka Nerd Font"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text; Layout.fillWidth: true }
                                        Rectangle {
                                            Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                            Layout.preferredWidth: root.s(40)
                                            Layout.preferredHeight: root.s(24)
                                            radius: root.s(12)
                                            color: root.setOpenGuideAtStartup ? root.peach : root.surface2
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                            Rectangle {
                                                width: root.s(18); height: root.s(18); radius: root.s(9); color: root.base
                                                y: root.s(3); x: root.setOpenGuideAtStartup ? root.s(19) : root.s(3)
                                                Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                            }
                                            MouseArea { anchors.fill: parent; onClicked: root.setOpenGuideAtStartup = !root.setOpenGuideAtStartup; cursorShape: Qt.PointingHandCursor }
                                        }
                                    }
                                    Text { text: "Launch on login"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true }
                                }
                            }
                            
                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(root.surface1, 0.5) }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: root.s(16)
                                Item {
                                    Layout.preferredWidth: root.s(24)
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: root.s(2)
                                    Text { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: "󰋖"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20); color: root.blue }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: root.s(4)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Help icon"; font.family: "Iosevka Nerd Font"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text; Layout.fillWidth: true }
                                        Rectangle {
                                            Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                            Layout.preferredWidth: root.s(40)
                                            Layout.preferredHeight: root.s(24)
                                            radius: root.s(12)
                                            color: root.setTopbarHelpIcon ? root.blue : root.surface2
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                            Rectangle {
                                                width: root.s(18); height: root.s(18); radius: root.s(9); color: root.base
                                                y: root.s(3); x: root.setTopbarHelpIcon ? root.s(19) : root.s(3)
                                                Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                            }
                                            MouseArea { anchors.fill: parent; onClicked: root.setTopbarHelpIcon = !root.setTopbarHelpIcon; cursorShape: Qt.PointingHandCursor }
                                        }
                                    }
                                    Text { text: "Show button in topbar"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true }
                                }
                            }
                        }
                    }

                    // Box 2: UI Scale
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: col2.implicitHeight + root.s(32)
                        radius: root.s(12)
                        color: Qt.alpha(root.surface0, 0.5)
                        border.color: root.surface1
                        border.width: 1
                        
                        ColumnLayout {
                            id: col2
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: root.s(16)
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: root.s(16)
                                Item {
                                    Layout.preferredWidth: root.s(24)
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: root.s(2)
                                    Text { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: "󰁦"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20); color: root.sapphire }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: root.s(4)
                                    Text { text: "UI Scale"; font.family: "Iosevka Nerd Font"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text; Layout.fillWidth: true }
                                    Text { text: "Base size scalar"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true }
                                    
                                    RowLayout {
                                        Layout.topMargin: root.s(8)
                                        spacing: root.s(12)
                                        Rectangle {
                                            width: root.s(30); height: root.s(30); radius: root.s(8)
                                            color: sMinusMa.pressed ? root.surface2 : root.surface1
                                            border.color: sMinusMa.containsMouse ? root.sapphire : "transparent"
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Text { anchors.centerIn: parent; text: "-"; font.family: "Iosevka Nerd Font"; font.weight: Font.Bold; font.pixelSize: root.s(16); color: root.text }
                                            MouseArea { id: sMinusMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.setUiScale = Math.max(0.5, (root.setUiScale - 0.1).toFixed(1)) }
                                        }
                                        Text { 
                                            text: root.setUiScale.toFixed(1) + "x"
                                            font.family: "Iosevka Nerd Font"
                                            font.weight: Font.Black
                                            font.pixelSize: root.s(14)
                                            color: root.sapphire
                                            Layout.minimumWidth: root.s(40)
                                            horizontalAlignment: Text.AlignHCenter 
                                        }
                                        Rectangle {
                                            width: root.s(30); height: root.s(30); radius: root.s(8)
                                            color: sPlusMa.pressed ? root.surface2 : root.surface1
                                            border.color: sPlusMa.containsMouse ? root.sapphire : "transparent"
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Text { anchors.centerIn: parent; text: "+"; font.family: "Iosevka Nerd Font"; font.weight: Font.Bold; font.pixelSize: root.s(16); color: root.text }
                                            MouseArea { id: sPlusMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.setUiScale = Math.min(2.0, (root.setUiScale + 0.1).toFixed(1)) }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                    }

                    // Box 3: Keyboard Language & Switcher
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: col3.implicitHeight + root.s(32)
                        radius: root.s(12)
                        color: Qt.alpha(root.surface0, 0.5)
                        border.color: root.surface1
                        border.width: 1
                        
                        ColumnLayout {
                            id: col3
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: root.s(16)
                            spacing: root.s(16)
                            
                            // Part 1: Language
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: root.s(16)
                                Item {
                                    Layout.preferredWidth: root.s(24)
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: root.s(2)
                                    Text { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: "󰌌"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20); color: root.green }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: root.s(4)
                                    Text { text: "Keyboard layouts"; font.family: "Iosevka Nerd Font"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text; Layout.fillWidth: true }
                                    Text { text: "Matches hyprland.conf. Click ✖ to remove."; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true }
                                    
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: root.s(8)
                                        Layout.topMargin: root.s(6)
                                        Repeater {
                                            model: root.setLanguage ? root.setLanguage.split(",").filter(x => x.trim() !== "") : []
                                            Rectangle {
                                                width: langChipLayout.implicitWidth + root.s(24)
                                                height: root.s(28)
                                                radius: root.s(14)
                                                color: root.surface1
                                                border.color: chipMa.containsMouse ? root.red : root.surface2
                                                border.width: 1
                                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                                RowLayout {
                                                    id: langChipLayout
                                                    anchors.centerIn: parent
                                                    spacing: root.s(8)
                                                    Text { 
                                                        text: modelData
                                                        font.family: "Iosevka Nerd Font"
                                                        font.weight: Font.Bold
                                                        font.pixelSize: root.s(12)
                                                        color: chipMa.containsMouse ? root.red : root.text 
                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                    }
                                                    Text { 
                                                        text: "✖"
                                                        font.family: "Iosevka Nerd Font"
                                                        font.pixelSize: root.s(13)
                                                        color: chipMa.containsMouse ? root.red : root.subtext0
                                                        Behavior on color { ColorAnimation { duration: 150 } } 
                                                    }
                                                }
                                                MouseArea {
                                                    id: chipMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        let arr = root.setLanguage.split(",").filter(x => x.trim() !== "");
                                                        arr.splice(index, 1);
                                                        root.setLanguage = arr.join(",");
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Search Bar Input
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: root.s(36)
                                        Layout.topMargin: root.s(8)
                                        radius: root.s(6)
                                        color: root.surface0
                                        border.color: langInput.activeFocus ? root.green : root.surface2
                                        border.width: 1
                                        Behavior on border.color { ColorAnimation { duration: 200 } }
                                        TextInput {
                                            id: langInput
                                            anchors.fill: parent
                                            anchors.margins: root.s(10)
                                            verticalAlignment: TextInput.AlignVCenter
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: root.s(12)
                                            color: root.text
                                            clip: true
                                            selectByMouse: true
                                            onTextChanged: { root.updateLangSearch(text); }
                                            onAccepted: root.saveAppSettings()
                                            Text { text: "Search to add..."; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                                        }
                                    }

                                    // Expanding List Container
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: langInput.activeFocus && langSearchModel.count > 0 ? Math.min(root.s(150), langSearchModel.count * root.s(32)) : 0
                                        radius: root.s(6)
                                        color: root.surface0
                                        border.color: root.green
                                        border.width: Layout.preferredHeight > 0 ? 1 : 0
                                        clip: true
                                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                        ListView {
                                            anchors.fill: parent
                                            model: langSearchModel
                                            interactive: true
                                            ScrollBar.vertical: ScrollBar { active: true; policy: ScrollBar.AsNeeded }
                                            delegate: Rectangle {
                                                width: parent.width
                                                height: root.s(32)
                                                color: sMa.containsMouse ? root.surface2 : "transparent"
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: root.s(12)
                                                    anchors.rightMargin: root.s(12)
                                                    spacing: root.s(10)
                                                    Text { text: model.code; font.family: "Iosevka Nerd Font"; font.weight: Font.Bold; font.pixelSize: root.s(12); color: root.text }
                                                    Text { text: model.name; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(11); color: root.subtext0; elide: Text.ElideRight; Layout.fillWidth: true }
                                                }
                                                MouseArea {
                                                    id: sMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        let arr = root.setLanguage ? root.setLanguage.split(",").filter(x => x.trim() !== "") : [];
                                                        if (!arr.includes(model.code)) {
                                                            arr.push(model.code);
                                                            root.setLanguage = arr.join(",");
                                                        }
                                                        langInput.text = "";
                                                        langInput.focus = false;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(root.surface1, 0.5) }

                            // Part 2: Layout Switcher
                            RowLayout {
                                id: layoutSwitcherBox
                                Layout.fillWidth: true
                                spacing: root.s(16)
                                property bool isDropdownOpen: false

                                Item {
                                    Layout.preferredWidth: root.s(24)
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: root.s(2)
                                    Text { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: "󰯍"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20); color: Qt.alpha(root.green, 0.7) }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: root.s(4)
                                    Text { text: "Layout shortcut"; font.family: "Iosevka Nerd Font"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text; Layout.fillWidth: true }
                                    Text { text: "Toggle combination"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true }

                                    // Switcher Selection Header
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: root.s(36)
                                        Layout.topMargin: root.s(8)
                                        radius: root.s(6)
                                        color: root.surface0
                                        border.color: layoutSwitcherBox.isDropdownOpen ? root.green : root.surface2
                                        border.width: 1
                                        Behavior on border.color { ColorAnimation { duration: 200 } }
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: root.s(10)
                                            Text { 
                                                text: root.getKbToggleLabel(root.setKbOptions)
                                                font.family: "Iosevka Nerd Font"
                                                font.pixelSize: root.s(12)
                                                color: root.text
                                                Layout.fillWidth: true 
                                            }
                                            Text { 
                                                text: layoutSwitcherBox.isDropdownOpen ? "▴" : "▾"
                                                font.pixelSize: root.s(14)
                                                color: root.subtext0 
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: layoutSwitcherBox.isDropdownOpen = !layoutSwitcherBox.isDropdownOpen
                                        }
                                    }

                                    // Expanding Switcher Dropdown
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: layoutSwitcherBox.isDropdownOpen ? root.kbToggleModelArr.length * root.s(32) : 0
                                        radius: root.s(6)
                                        color: root.surface0
                                        border.color: root.green
                                        border.width: Layout.preferredHeight > 0 ? 1 : 0
                                        clip: true
                                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                        ListView {
                                            anchors.fill: parent
                                            model: root.kbToggleModelArr
                                            interactive: false
                                            delegate: Rectangle {
                                                width: parent.width
                                                height: root.s(32)
                                                color: toggleMa.containsMouse ? root.surface2 : "transparent"
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: root.s(12)
                                                    anchors.rightMargin: root.s(12)
                                                    Text { 
                                                        text: modelData.label
                                                        font.family: "Iosevka Nerd Font"
                                                        font.pixelSize: root.s(12)
                                                        color: root.setKbOptions === modelData.val ? root.green : root.text
                                                        Layout.fillWidth: true 
                                                    }
                                                }
                                                MouseArea {
                                                    id: toggleMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.setKbOptions = modelData.val;
                                                        layoutSwitcherBox.isDropdownOpen = false;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Box 4: Wallpaper Directory
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: col4.implicitHeight + root.s(32)
                        radius: root.s(12)
                        color: Qt.alpha(root.surface0, 0.5)
                        border.color: wpDirInput.activeFocus ? root.mauve : root.surface1
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        
                        ColumnLayout {
                            id: col4
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: root.s(16)
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: root.s(16)
                                Item {
                                    Layout.preferredWidth: root.s(24)
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: root.s(2)
                                    Text { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20); color: root.mauve }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: root.s(4)
                                    Text { text: "Wallpaper directory"; font.family: "Iosevka Nerd Font"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text; Layout.fillWidth: true }
                                    Text { text: "Absolute source path"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true }
                                    
                                    // Text Input
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: root.s(36)
                                        Layout.topMargin: root.s(8)
                                        radius: root.s(6)
                                        color: root.surface0
                                        border.color: wpDirInput.activeFocus ? root.mauve : root.surface2
                                        border.width: 1
                                        Behavior on border.color { ColorAnimation { duration: 200 } }
                                        TextInput {
                                            id: wpDirInput
                                            anchors.fill: parent
                                            anchors.margins: root.s(10)
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: root.setWallpaperDir
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: root.s(12)
                                            color: root.text
                                            clip: true
                                            selectByMouse: true
                                            onTextChanged: { 
                                                root.setWallpaperDir = text; 
                                                if (activeFocus) { 
                                                    pathSuggestProc.query = text; 
                                                    pathSuggestProc.running = false; 
                                                    pathSuggestProc.running = true; 
                                                } 
                                            }
                                            onAccepted: root.saveAppSettings()
                                        }
                                    }

                                    // Expanding Suggestions List
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: wpDirInput.activeFocus && pathSuggestModel.count > 0 ? pathSuggestModel.count * root.s(30) : 0
                                        radius: root.s(6)
                                        color: root.surface0
                                        border.color: root.mauve
                                        border.width: Layout.preferredHeight > 0 ? 1 : 0
                                        clip: true
                                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                        ListView {
                                            anchors.fill: parent
                                            model: pathSuggestModel
                                            interactive: false
                                            delegate: Rectangle {
                                                width: parent.width
                                                height: root.s(30)
                                                color: suggestMa.containsMouse ? root.surface2 : "transparent"
                                                Text { 
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: root.s(12)
                                                    text: model.path
                                                    font.family: "Iosevka Nerd Font"
                                                    font.pixelSize: root.s(11)
                                                    color: root.text
                                                    elide: Text.ElideMiddle
                                                    width: parent.width - root.s(24) 
                                                }
                                                MouseArea {
                                                    id: suggestMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: { 
                                                        wpDirInput.text = model.path; 
                                                        pathSuggestModel.clear(); 
                                                        wpDirInput.focus = false; 
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Box 5: Workspace Count
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: col5.implicitHeight + root.s(32)
                        radius: root.s(12)
                        color: Qt.alpha(root.surface0, 0.5)
                        border.color: root.surface1
                        border.width: 1
                        
                        ColumnLayout {
                            id: col5
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: root.s(16)
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: root.s(16)
                                Item {
                                    Layout.preferredWidth: root.s(24)
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: root.s(2)
                                    Text { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: "󰽿"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20); color: root.yellow }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: root.s(4)
                                    Text { text: "Workspaces"; font.family: "Iosevka Nerd Font"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text; Layout.fillWidth: true }
                                    Text { text: "Static count in topbar"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true }
                                    
                                    RowLayout {
                                        Layout.topMargin: root.s(8)
                                        spacing: root.s(12)
                                        Rectangle {
                                            width: root.s(30); height: root.s(30); radius: root.s(8)
                                            color: wsMinusMa.pressed ? root.surface2 : root.surface1
                                            border.color: wsMinusMa.containsMouse ? root.yellow : "transparent"
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Text { anchors.centerIn: parent; text: "-"; font.family: "Iosevka Nerd Font"; font.weight: Font.Bold; font.pixelSize: root.s(16); color: root.text }
                                            MouseArea { id: wsMinusMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.setWorkspaceCount = Math.max(1, root.setWorkspaceCount - 1) }
                                        }
                                        Text { 
                                            text: root.setWorkspaceCount.toString()
                                            font.family: "Iosevka Nerd Font"
                                            font.weight: Font.Black
                                            font.pixelSize: root.s(14)
                                            color: root.yellow
                                            Layout.minimumWidth: root.s(40)
                                            horizontalAlignment: Text.AlignHCenter 
                                        }
                                        Rectangle {
                                            width: root.s(30); height: root.s(30); radius: root.s(8)
                                            color: wsPlusMa.pressed ? root.surface2 : root.surface1
                                            border.color: wsPlusMa.containsMouse ? root.yellow : "transparent"
                                            border.width: 1
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Text { anchors.centerIn: parent; text: "+"; font.family: "Iosevka Nerd Font"; font.weight: Font.Bold; font.pixelSize: root.s(16); color: root.text }
                                            MouseArea { id: wsPlusMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.setWorkspaceCount = Math.min(20, root.setWorkspaceCount + 1) }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                    }

                }
            }
            
            // --- NEW PILL SAVE BUTTON ---
            Rectangle {
                id: floatingSaveBtn
                width: saveRow.implicitWidth + root.s(32)
                height: root.s(40)
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: root.s(24)
                radius: height / 2
                color: mainSaveMa.pressed ? Qt.darker(root.mauve, 1.2) : (mainSaveMa.containsMouse ? root.mauve : root.surface0)
                border.color: root.mauve
                border.width: 1
                
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    id: saveRow
                    anchors.centerIn: parent
                    spacing: root.s(8)
                    
                    Text {
                        text: "󰆓"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: root.s(18)
                        color: mainSaveMa.containsMouse ? root.crust : root.mauve
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text: "Apply"
                        font.family: "Iosevka Nerd Font"
                        font.weight: Font.Bold
                        font.pixelSize: root.s(13)
                        color: mainSaveMa.containsMouse ? root.crust : root.text
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                
                MouseArea { 
                    id: mainSaveMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.saveAppSettings() 
                }
            }
        }
    }
}
