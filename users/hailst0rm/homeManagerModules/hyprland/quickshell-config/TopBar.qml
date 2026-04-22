//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland


Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
	    id: barWindow

	    property bool pendingReload: false

	    IpcHandler {
    		target: "topbar"
    
    		function forceReload() {
            	    Quickshell.reload(true) 
	        }

	        function queueReload() {
                    // If it's already closed, reload immediately. Otherwise, flag it.
                    if (!barWindow.isSettingsOpen && barWindow.sidebarHoleWidth <= 0.01) {
                        Quickshell.reload(true)
                    } else {
                        barWindow.pendingReload = true
                    }
                }
	    }

            required property var modelData
            
            // Bind this specific bar instance to the dynamically assigned screen
            screen: modelData
            
            anchors {
                top: true
                left: true
                right: true
            }
            
            // --- Responsive Scaling Logic ---
            Scaler {
                id: scaler
                currentWidth: barWindow.width
            }

            property real baseScale: scaler.baseScale
            
            // Helper function mapped to the external scaler
            function s(val) { 
                return scaler.s(val); 
            }

            property string iconFont: "Iosevka Nerd Font"
            property string textFont: "JetBrainsMono Nerd Font"

            property int barHeight: s(48)

            // THICKER BAR, MINIMAL MARGINS (Scaled)
            height: barHeight
            margins { top: s(8); bottom: 0; left: s(4); right: s(4) }
            
            // exclusiveZone = height + top margin
            exclusiveZone: barHeight + s(4)
            color: "transparent"

            // Dynamic Matugen Palette
            MatugenColors {
                id: mocha
            }

            // NixOS system config (accent color, laptop flag)
            SystemConfig {
                id: sysConfig
            }

            // --- State Variables ---
            property bool showHelpIcon: true
            property bool isRecording: false // Track screen recording
            property bool updateAvailable: false // Track pending updates
            property int workspaceCount: 5
            
            // Tracks current qs widget to coordinate the sidebar transitions
            property string activeWidget: "" 
            property bool isSettingsOpen: activeWidget === "settings"

            // --- Dynamic Window Mask ---
            // Cuts a physical hole in the TopBar window so the Sidebar can occupy the top-left edge
            property real targetSidebarHoleWidth: isSettingsOpen ? s(420) : 0
            property real sidebarHoleWidth: targetSidebarHoleWidth
            Behavior on sidebarHoleWidth { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }

            mask: Region { item: sidebarHole; intersection: Intersection.Xor }
            
            Item {
                id: sidebarHole
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: barWindow.sidebarHoleWidth
            }

            // Background poller for active widget state tracking
            Process {
                id: widgetPoller
                command: ["bash", "-c", "cat /tmp/qs_current_widget 2>/dev/null || echo ''"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (barWindow.activeWidget !== txt) barWindow.activeWidget = txt;
                    }
                }
            }

            Process {
                id: widgetWatcher
                command: ["bash", "-c", "while [ ! -f /tmp/qs_current_widget ]; do sleep 1; done; inotifywait -qq -e modify,close_write /tmp/qs_current_widget"]
                running: true
                onExited: {
                    widgetPoller.running = false;
                    widgetPoller.running = true;
                    running = false;
                    running = true;
                }
            }
            
            // Background poller to check if gpu-screen-recorder is active via its PID file
            Process {
                id: recPoller
                command: ["bash", "-c", "if [ -s ~/.cache/qs_recording_state/rec_pid ] && kill -0 $(cat ~/.cache/qs_recording_state/rec_pid) 2>/dev/null; then echo '1'; else echo '0'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isRecording = (this.text.trim() === "1");
                    }
                }
            }

            Timer {
                interval: 500; running: true; repeat: true
                onTriggered: {
                    recPoller.running = false;
                    recPoller.running = true;
                }
            }

            // Background poller to check for pending updates
            Process {
                id: updatePoller
                command: ["bash", "-c", "if [ -f ~/.cache/qs_update_pending ]; then echo '1'; else echo '0'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.updateAvailable = (this.text.trim() === "1");
                    }
                }
            }

            Timer {
                interval: 2000; running: true; repeat: true
                onTriggered: {
                    updatePoller.running = false;
                    updatePoller.running = true;
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
                                
                                if (parsed.topbarHelpIcon !== undefined && barWindow.showHelpIcon !== parsed.topbarHelpIcon) {
                                    barWindow.showHelpIcon = parsed.topbarHelpIcon;
                                }
                                
                                // Detect if workspace count changed and restart the bash script
                                if (parsed.workspaceCount !== undefined && barWindow.workspaceCount !== parsed.workspaceCount) {
                                    barWindow.workspaceCount = parsed.workspaceCount;
                                    wsDaemon.running = false;
                                    wsDaemon.running = true;
                                }
                            }
                        } catch (e) {}
                    }
                }
            }
            // EVENT-DRIVEN WATCHER FOR SETTINGS
            Process {
                id: settingsWatcher
                command: ["bash", "-c", "while [ ! -f ~/.config/hypr/settings.json ]; do sleep 1; done; inotifywait -qq -e modify,close_write ~/.config/hypr/settings.json"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        settingsReader.running = false;
                        settingsReader.running = true;
                        
                        settingsWatcher.running = false;
                        settingsWatcher.running = true;
                    }
                }
            }
            
            // Desktop Chassis Detection
            property bool isDesktop: false
            property string ethStatus: "Ethernet"

            Process {
                id: chassisDetector
                running: true
                command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isDesktop = (this.text.trim() === "desktop");
                    }
                }
            }

            // Triggers layout animations immediately to feel fast
            property bool isStartupReady: false
            Timer { interval: 10; running: true; onTriggered: barWindow.isStartupReady = true }
            
            // Prevents repeaters (Workspaces/Tray) from flickering on data updates
            property bool startupCascadeFinished: false
            Timer { interval: 1000; running: true; onTriggered: barWindow.startupCascadeFinished = true }
            
            // Data gating to prevent startup layout jumping
            property bool fastPollerLoaded: false
            
            property bool isDataReady: fastPollerLoaded
            // Failsafe: Force the layout to show after 600ms even if fast poller hangs
            Timer { interval: 600; running: true; onTriggered: barWindow.isDataReady = true }
            
            property string timeStr: ""
            property string fullDateStr: ""
            property int typeInIndex: 0
            property string dateStr: fullDateStr.substring(0, typeInIndex)

            property string weatherIcon: ""
            property string weatherTemp: "--°"
            property string weatherHex: mocha.yellow
            
            property string wifiStatus: "Off"
            property string wifiIcon: "󰤮"
            property string wifiSsid: ""
            
            property string btStatus: "Off"
            property string btIcon: "󰂲"
            property string btDevice: ""
            
            property string volPercent: "0%"
            property string volIcon: "󰕾"
            property bool isMuted: false
            
            property string batPercent: "100%"
            property string batIcon: "󰁹"
            property string batStatus: "Unknown"
            
            property string kbLayout: "us"
            
            ListModel { id: workspacesModel }
            
            property var musicData: { "status": "Stopped", "title": "", "artUrl": "", "timeStr": "" }

            // Derived properties for UI logic
            property bool isMediaActive: barWindow.musicData.status !== "Stopped" && barWindow.musicData.title !== ""
            property bool isWifiOn: barWindow.wifiStatus.toLowerCase() === "enabled" || barWindow.wifiStatus.toLowerCase() === "on"
            property bool isBtOn: barWindow.btStatus.toLowerCase() === "enabled" || barWindow.btStatus.toLowerCase() === "on"
            property bool showEthernet: barWindow.isDesktop && !barWindow.isWifiOn
            
            property bool isSoundActive: !barWindow.isMuted && parseInt(barWindow.volPercent) > 0
            property int batCap: parseInt(barWindow.batPercent) || 0
            property bool isCharging: barWindow.batStatus === "Charging" || barWindow.batStatus === "Full"
            
            property color batDynamicColor: {
                if (isCharging) return mocha.green;
                if (batCap <= 20) return mocha.red;
                return mocha.text; 
            }

            // ==========================================
            // DATA FETCHING 
            // ==========================================

            // Workspaces --------------------------------
            Process {
                id: wsDaemon
                command: ["bash", "-c", "~/.config/quickshell/workspaces.sh"]
                running: true
            }

            // Per-monitor workspace file (hyprsplit: each monitor has its own workspace set)
            property string wsFile: "/tmp/qs_workspaces_" + barWindow.modelData.name + ".json"

            Process {
                id: wsReader
                command: ["bash", "-c", "cat '" + barWindow.wsFile + "' 2>/dev/null || cat /tmp/qs_workspaces.json 2>/dev/null || echo '[]'"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let newData = JSON.parse(txt);

                                // 1. Add missing items if the user increased the workspace count
                                while (workspacesModel.count < newData.length) {
                                    workspacesModel.append({ "wsId": "", "wsState": "", "wsRealId": "" });
                                }

                                // 2. Remove excess items if the user decreased the workspace count
                                while (workspacesModel.count > newData.length) {
                                    workspacesModel.remove(workspacesModel.count - 1);
                                }

                                // 3. Update all properties smoothly without breaking bindings
                                for (let i = 0; i < newData.length; i++) {
                                    if (workspacesModel.get(i).wsState !== newData[i].state) {
                                        workspacesModel.setProperty(i, "wsState", newData[i].state);
                                    }
                                    let displayId = newData[i].id.toString();
                                    if (workspacesModel.get(i).wsId !== displayId) {
                                        workspacesModel.setProperty(i, "wsId", displayId);
                                    }
                                    // Store real hyprsplit workspace ID for switching
                                    let realId = (newData[i].real_id !== undefined ? newData[i].real_id : newData[i].id).toString();
                                    if (workspacesModel.get(i).wsRealId !== realId) {
                                        workspacesModel.setProperty(i, "wsRealId", realId);
                                    }
                    }
                            } catch(e) {}
                        }
                    }
                }
            }

            Process {
                id: wsWatcher
                running: true
                command: ["bash", "-c", "f='" + barWindow.wsFile + "'; [ -f \"$f\" ] || f=/tmp/qs_workspaces.json; inotifywait -qq -e close_write,modify \"$f\""]
                onExited: {
                    wsReader.running = false;
                    wsReader.running = true;
                    running = false;
                    running = true;
                }
            }

            // Music -------------------------------------
            Process {
                id: musicForceRefresh
                running: true
                command: ["bash", "-c", "bash ~/.config/quickshell/music/music_info.sh | tee /tmp/music_info.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { barWindow.musicData = JSON.parse(txt); } catch(e) {}
                        }
                    }
                }
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    if (!barWindow.musicData || barWindow.musicData.status !== "Playing") return;
                    if (!barWindow.musicData.timeStr || barWindow.musicData.timeStr === "") return;

                    let parts = barWindow.musicData.timeStr.split(" / ");
                    if (parts.length !== 2) return;

                    let posParts = parts[0].split(":").map(Number);
                    let lenParts = parts[1].split(":").map(Number);

                    let posSecs = (posParts.length === 3) 
                        ? (posParts[0] * 3600 + posParts[1] * 60 + posParts[2]) 
                        : (posParts[0] * 60 + posParts[1]);

                    let lenSecs = (lenParts.length === 3) 
                        ? (lenParts[0] * 3600 + lenParts[1] * 60 + lenParts[2]) 
                        : (lenParts[0] * 60 + lenParts[1]);

                    if (isNaN(posSecs) || isNaN(lenSecs)) return;

                    posSecs++;
                    if (posSecs > lenSecs) posSecs = lenSecs;

                    let newPosStr = "";
                    if (posParts.length === 3) {
                        let h = Math.floor(posSecs / 3600);
                        let m = Math.floor((posSecs % 3600) / 60);
                        let s = posSecs % 60;
                        newPosStr = h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    } else {
                        let m = Math.floor(posSecs / 60);
                        let s = posSecs % 60;
                        newPosStr = (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    }

                    let newData = Object.assign({}, barWindow.musicData);
                    newData.timeStr = newPosStr + " / " + parts[1];
                    newData.positionStr = newPosStr;
                    if (lenSecs > 0) newData.percent = (posSecs / lenSecs) * 100;
                    
                    barWindow.musicData = newData;
                }
            }

            Process {
                id: mprisWatcher
                running: true
                command: ["bash", "-c", "dbus-monitor --session \"type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.mpris.MediaPlayer2.Player'\" \"type='signal',interface='org.mpris.MediaPlayer2.Player',member='Seeked'\" 2>/dev/null | grep -m 1 'member=' > /dev/null || sleep 2"]
                onExited: {
                    musicForceRefresh.running = false;
                    musicForceRefresh.running = true;
                    running = false;
                    running = true;
                }
            }

            // ==========================================
            // MODULAR SYSTEM WATCHERS
            // ==========================================

            // --- KEYBOARD ---
            Process {
                id: kbPoller; running: true
                command: ["bash", "-c", "~/.config/quickshell/watchers/kb_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "" && barWindow.kbLayout !== txt) barWindow.kbLayout = txt;
                        kbWaiter.running = false;
                        kbWaiter.running = true;
                        barWindow.fastPollerLoaded = true; // Gating flag
                    }
                }
            }
            Process { id: kbWaiter; command: ["bash", "-c", "~/.config/quickshell/watchers/kb_wait.sh"]; onExited: { kbPoller.running = false; kbPoller.running = true; } }

            // --- AUDIO ---
            Process {
                id: audioPoller; running: true
                command: ["bash", "-c", "~/.config/quickshell/watchers/audio_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                let newVol = data.volume.toString() + "%";
                                if (barWindow.volPercent !== newVol) barWindow.volPercent = newVol;
                                if (barWindow.volIcon !== data.icon) barWindow.volIcon = data.icon;
                                let newMuted = (data.is_muted === "true");
                                if (barWindow.isMuted !== newMuted) barWindow.isMuted = newMuted;
                            } catch(e) {}
                        }
                        audioWaiter.running = false;
                        audioWaiter.running = true;
                    }
                }
            }
            Process { id: audioWaiter; command: ["bash", "-c", "~/.config/quickshell/watchers/audio_wait.sh"]; onExited: { audioPoller.running = false; audioPoller.running = true; } }

            // --- NETWORK ---
            Process {
                id: networkPoller; running: true
                command: ["bash", "-c", "~/.config/quickshell/watchers/network_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                if (barWindow.wifiStatus !== data.status) barWindow.wifiStatus = data.status;
                                if (barWindow.wifiIcon !== data.icon) barWindow.wifiIcon = data.icon;
                                if (barWindow.wifiSsid !== data.ssid) barWindow.wifiSsid = data.ssid;
                                if (barWindow.ethStatus !== data.eth_status) barWindow.ethStatus = data.eth_status;
                            } catch(e) {}
                        }
                        networkWaiter.running = false;
                        networkWaiter.running = true;
                    }
                }
            }
        Process { id: networkWaiter; command: ["bash", "-c", "~/.config/quickshell/watchers/network_wait.sh"]; onExited: { networkPoller.running = false; networkPoller.running = true; } }

            // --- BLUETOOTH ---
            Process {
                id: btPoller; running: true
                command: ["bash", "-c", "~/.config/quickshell/watchers/bt_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                if (barWindow.btStatus !== data.status) barWindow.btStatus = data.status;
                                if (barWindow.btIcon !== data.icon) barWindow.btIcon = data.icon;
                                if (barWindow.btDevice !== data.connected) barWindow.btDevice = data.connected;
                            } catch(e) {}
                        }
                        btWaiter.running = false;
                        btWaiter.running = true;
                    }
                }
            }
            Process { id: btWaiter; command: ["bash", "-c", "~/.config/quickshell/watchers/bt_wait.sh"]; onExited: { btPoller.running = false; btPoller.running = true; } }

            // --- BATTERY ---
            Process {
                id: batteryPoller; running: true
                command: ["bash", "-c", "~/.config/quickshell/watchers/battery_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                let newBat = data.percent.toString() + "%";
                                if (barWindow.batPercent !== newBat) barWindow.batPercent = newBat;
                                if (barWindow.batIcon !== data.icon) barWindow.batIcon = data.icon;
                                if (barWindow.batStatus !== data.status) barWindow.batStatus = data.status;
                            } catch(e) {}
                        }
                        batteryWaiter.running = false;
                        batteryWaiter.running = true;
                    }
                }
            }
            Process { id: batteryWaiter; command: ["bash", "-c", "~/.config/quickshell/watchers/battery_wait.sh"]; onExited: { batteryPoller.running = false; batteryPoller.running = true; } }


            Process {
                id: weatherPoller
                command: ["bash", "-c", `
                    echo "$(~/.config/quickshell/calendar/weather.sh --current-icon)"
                    echo "$(~/.config/quickshell/calendar/weather.sh --current-temp)"
                    echo "$(~/.config/quickshell/calendar/weather.sh --current-hex)"
                `]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let lines = this.text.trim().split("\n");
                        if (lines.length >= 3) {
                            barWindow.weatherIcon = lines[0];
                            barWindow.weatherTemp = lines[1].replace(/[\d.]+/, function(m) { return Math.round(parseFloat(m)); });
                            barWindow.weatherHex = lines[2] || mocha.yellow;
                        }
                    }
                }
            }
            Timer { interval: 150000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { weatherPoller.running = false; weatherPoller.running = true; } }


            // Native Qt Time Formatting
            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let d = new Date();
                    barWindow.timeStr = Qt.formatDateTime(d, "HH:mm:ss");
                    // ISO week number
                    let jan1 = new Date(d.getFullYear(), 0, 1);
                    let days = Math.floor((d - jan1) / 86400000);
                    let weekNum = Math.ceil((days + jan1.getDay() + 1) / 7);
                    barWindow.fullDateStr = Qt.formatDateTime(d, "dddd, MMMM dd") + " (w. " + weekNum + ")";
                    if (barWindow.typeInIndex >= barWindow.fullDateStr.length) {
                        barWindow.typeInIndex = barWindow.fullDateStr.length;
                    }
                }
            }

            // Typewriter effect timer for the date
            Timer {
                id: typewriterTimer
                interval: 40
                running: barWindow.isStartupReady && barWindow.typeInIndex < barWindow.fullDateStr.length
                repeat: true
                onTriggered: barWindow.typeInIndex += 1
            }

            // ==========================================
            // UI LAYOUT
            // ==========================================
            Item {
                anchors.fill: parent

                // ---------------- LEFT CONTENT ----------------
                Rectangle {
                    id: leftContent
                    y: (parent.height - barWindow.barHeight) / 2
                    height: barWindow.barHeight

                    // Base unified styling (matches the right system pills)
                    color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                    radius: height / 2
                    border.width: 1
                    border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                    clip: true
                    
                    property bool showLayout: false
                    
                    // Slide to the left seamlessly, fade out, and disable clicks so the settings panel underneath can be interacted with.
                    opacity: (showLayout && !barWindow.isSettingsOpen) ? 1 : 0
                    enabled: !barWindow.isSettingsOpen
                    
                    property real targetX: (showLayout && !barWindow.isSettingsOpen) ? 0 : barWindow.s(-200)
                    x: targetX
                    Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    
                    Timer {
                        running: barWindow.isStartupReady
                        interval: 10
                        onTriggered: leftContent.showLayout = true
                    }

                    // Smooth dynamic width calculation based on inner layout
                    property real targetWidth: leftLayout.width + barWindow.s(16) // 8px horizontal padding on each side
                    width: targetWidth
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                    Row {
                        id: leftLayout
                        anchors.centerIn: parent
                        spacing: barWindow.s(4)
                        
                        property int pillHeight: barWindow.s(34)

                        // Help
                        Rectangle {
                            property bool isHovered: helpMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : "transparent"
                            radius: height / 2
                            
                            property real targetWidth: barWindow.showHelpIcon ? barWindow.s(34) : 0
                            width: targetWidth
                            height: parent.pillHeight
                            visible: targetWidth > 0 || opacity > 0
                            opacity: barWindow.showHelpIcon ? 1.0 : 0.0
                            clip: true
                            
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󱄅"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(22)
                                color: parent.isHovered ? sysConfig.accent : "#ffffff"
                                Behavior on color { ColorAnimation { duration: 200 } }
                                scale: parent.isHovered ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            }
                            MouseArea {
                                id: helpMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/quickshell/qs_manager.sh toggle guide"])
                            }
                        }

                        // Update Button
                        Rectangle {
                            id: updateButton
                            property bool isHovered: updateMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : "transparent"
                            radius: height / 2
                            
                            property real targetWidth: barWindow.updateAvailable ? barWindow.s(34) : 0
                            width: targetWidth
                            height: parent.pillHeight
                            
                            visible: targetWidth > 0 || opacity > 0
                            opacity: barWindow.updateAvailable ? 1.0 : 0.0
                            clip: true
                            
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            property color pulseColor: mocha.green
                            SequentialAnimation on pulseColor {
                                running: barWindow.updateAvailable
                                loops: Animation.Infinite
                                ColorAnimation { to: mocha.teal; duration: 1500; easing.type: Easing.InOutSine }
                                ColorAnimation { to: mocha.green; duration: 1500; easing.type: Easing.InOutSine }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰚰" // package/update icon
                                font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(22)
                                color: parent.isHovered ? mocha.text : parent.pulseColor
                                Behavior on color { ColorAnimation { duration: 200 } }
                                scale: parent.isHovered ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            }

                            MouseArea {
                                id: updateMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    barWindow.updateAvailable = false;
                                    Quickshell.execDetached(["bash", "-c", "rm -f ~/.cache/qs_update_pending && ~/.config/quickshell/qs_manager.sh toggle updater"]);
                                }
                            }
                        }
                    }
                }
                // ---------------- WORKSPACES ----------------
                Rectangle {
                    id: workspacesBox
                    color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                    radius: height / 2; border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                    height: barWindow.barHeight
                    y: (parent.height - barWindow.barHeight) / 2
                    clip: true
                    
                    // Uses targetWidth instead of active width for layout chaining to prevent Behavior delay loops
                    property real targetWidth: workspacesModel.count > 0 ? wsLayout.implicitWidth + barWindow.s(32) : 0
                    
                    // Left-to-Right train logic (Settings Closed)
                    property real defaultX: leftContent.width + barWindow.s(8)
                    // Right-to-Left train logic (Settings Open)
                    property real settingsX: centerBox.settingsX - targetWidth - (targetWidth > 0 ? barWindow.s(8) : 0)
                    
                    property real targetX: barWindow.isSettingsOpen ? settingsX : defaultX
                    x: targetX
                    Behavior on x { 
                        enabled: barWindow.startupCascadeFinished
                        NumberAnimation { duration: 600; easing.type: Easing.OutExpo } 
                    }

                    width: targetWidth
                    visible: targetWidth > 0 || opacity > 0
                    opacity: workspacesModel.count > 0 ? 1 : 0
                    
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                    Behavior on opacity { NumberAnimation { duration: 300 } }

                    Row {
                        id: wsLayout
                        anchors.centerIn: parent
                        spacing: barWindow.s(12)

                        Repeater {
                            model: workspacesModel
                            delegate: Rectangle {
                                id: wsPill

                                property bool isHovered: wsPillMouse.containsMouse
                                property string stateLabel: model.wsState
                                property string wsName: model.wsId
                                property string wsRealId: model.wsRealId || model.wsId

                                // Active = wide pill, others = dot
                                property real dotSize: barWindow.s(14)
                                property real pillWidth: barWindow.s(36)

                                width: stateLabel === "active" ? pillWidth : dotSize
                                height: dotSize
                                radius: dotSize / 2

                                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                                color: stateLabel === "active"
                                        ? sysConfig.accent
                                        : (isHovered
                                            ? mocha.overlay1
                                            : (stateLabel === "occupied"
                                                ? mocha.text
                                                : mocha.overlay0))

                                scale: isHovered ? 1.2 : 1.0
                                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                                property bool initAnimTrigger: false
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate {
                                    y: wsPill.initAnimTrigger ? 0 : barWindow.s(15)
                                    Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                                }

                                Component.onCompleted: {
                                    if (!barWindow.startupCascadeFinished) {
                                        animTimer.interval = index * 60;
                                        animTimer.start();
                                    } else {
                                        initAnimTrigger = true;
                                    }
                                }

                                Timer {
                                    id: animTimer
                                    running: false
                                    repeat: false
                                    onTriggered: wsPill.initAnimTrigger = true
                                }

                                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 250 } }

                                MouseArea {
                                    id: wsPillMouse
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/quickshell/qs_manager.sh " + wsRealId])
                                }
                            }
                        }
                    }
                }

                // ---------------- CENTER BOX ----------------
                Rectangle {
                    id: centerBox
                    property bool isHovered: centerMouse.containsMouse
                    color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.95) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                    radius: height / 2; border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, isHovered ? 0.15 : 0.05)
                    
                    y: (parent.height - barWindow.barHeight) / 2
                    height: barWindow.barHeight
                    
                    property real targetWidth: centerLayout.implicitWidth + barWindow.s(36)
                    width: targetWidth
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                    
                    // Left-to-Right train logic (Settings Closed) - Takes absolute center if not overflowing
                    property real pureCenter: (parent.width - targetWidth) / 2
                    property real minCenterDefaultX: workspacesBox.defaultX + workspacesBox.targetWidth + (workspacesBox.targetWidth > 0 ? barWindow.s(8) : 0)
                    property real defaultX: Math.max(minCenterDefaultX, pureCenter)
                    
                    // Right-to-Left train logic (Settings Open) - Anchors tightly to the far right modules
                    property real settingsX: barWindow.width - rightContent.width - targetWidth - barWindow.s(8)
                    
                    property real targetX: barWindow.isSettingsOpen ? settingsX : defaultX
                    x: targetX
                    Behavior on x { 
                        enabled: barWindow.startupCascadeFinished
                        NumberAnimation { duration: 600; easing.type: Easing.OutExpo } 
                    }
                    
                    // Staggered Center Transition (Vertical)
                    property bool showLayout: false
                    opacity: showLayout ? 1 : 0
                    transform: Translate {
                        y: centerBox.showLayout ? 0 : barWindow.s(-30)
                        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    }

                    Timer {
                        running: barWindow.isStartupReady
                        interval: 150
                        onTriggered: centerBox.showLayout = true
                    }

                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                    // Hover Scaling
                    scale: isHovered ? 1.03 : 1.0
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                    
                    MouseArea {
                        id: centerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/quickshell/qs_manager.sh toggle calendar"])
                    }

                    RowLayout {
                        id: centerLayout
                        anchors.centerIn: parent
                        spacing: barWindow.s(24)

                        // Clockbox
                        ColumnLayout {
                            spacing: -2
                            Text { text: barWindow.timeStr; Layout.alignment: Qt.AlignHCenter; font.family: barWindow.textFont; font.pixelSize: barWindow.s(16); font.weight: Font.Black; color: mocha.text }
                            Text { text: barWindow.dateStr; Layout.alignment: Qt.AlignHCenter; font.family: barWindow.textFont; font.pixelSize: barWindow.s(11); font.weight: Font.Bold; color: mocha.subtext0 }
                        }

                        // Weatherbox
                        RowLayout {
                            spacing: barWindow.s(8)
                            Text { 
                                text: barWindow.weatherIcon; 
                                Layout.alignment: Qt.AlignVCenter;
                                font.family: "Iosevka Nerd Font"; 
                                font.pixelSize: barWindow.s(24); 
                                color: Qt.tint(barWindow.weatherHex, Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.4)) 
                            }
                            Text { 
                                text: barWindow.weatherTemp;
                                Layout.alignment: Qt.AlignVCenter;
                                font.family: barWindow.textFont;
                                font.pixelSize: barWindow.s(17); 
                                font.weight: Font.Black; 
                                color: mocha.text
                            }
                        }
                    }
                }

                // ---------------- RIGHT CONTENT ----------------
                Row {
                    id: rightContent
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: barWindow.s(4)
                    
                    property bool showLayout: false
                    opacity: showLayout ? 1 : 0
                    transform: Translate {
                        x: rightContent.showLayout ? 0 : barWindow.s(30)
                        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    }
                    
                    Timer {
                        running: barWindow.isStartupReady && barWindow.isDataReady
                        interval: 250
                        onTriggered: rightContent.showLayout = true
                    }

                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                    // Media Player Pill (shown when music is active)
                    Rectangle {
                        height: barWindow.barHeight
                        radius: height / 2
                        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                        border.width: 1
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        clip: true

                        property real targetWidth: barWindow.isMediaActive ? mediaInnerLayout.width + barWindow.s(24) : 0
                        width: targetWidth
                        visible: targetWidth > 0 || opacity > 0
                        opacity: barWindow.isMediaActive ? 1.0 : 0.0

                        Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 400 } }

                        Row {
                            id: mediaInnerLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(10)

                            MouseArea {
                                id: mediaInfoMouse
                                width: infoLayout.width
                                height: mediaInnerLayout.height
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/quickshell/qs_manager.sh toggle music"])

                                Row {
                                    id: infoLayout
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: barWindow.s(8)
                                    scale: mediaInfoMouse.containsMouse ? 1.02 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                    Rectangle {
                                        width: barWindow.s(28); height: barWindow.s(28); radius: barWindow.s(6); color: mocha.surface1
                                        border.width: barWindow.musicData.status === "Playing" ? 1 : 0
                                        border.color: mocha.mauve; clip: true
                                        Image { anchors.fill: parent; source: barWindow.musicData.artUrl || ""; fillMode: Image.PreserveAspectCrop }
                                        Rectangle { anchors.fill: parent; color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.2) }
                                    }
                                    Column {
                                        spacing: -2
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: barWindow.s(140)
                                        Text { text: barWindow.musicData.title; font.family: barWindow.textFont; font.weight: Font.Black; font.pixelSize: barWindow.s(11); color: mocha.text; width: parent.width; elide: Text.ElideRight }
                                        Text { text: barWindow.musicData.timeStr; font.family: barWindow.textFont; font.weight: Font.Black; font.pixelSize: barWindow.s(9); color: mocha.subtext0; width: parent.width; elide: Text.ElideRight }
                                    }
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: barWindow.s(4)
                                Item {
                                    width: barWindow.s(20); height: barWindow.s(20); anchors.verticalCenter: parent.verticalCenter
                                    Text { anchors.centerIn: parent; text: "󰒮"; font.family: barWindow.iconFont; font.pixelSize: barWindow.s(22); color: prevMouse.containsMouse ? mocha.text : mocha.overlay2; Behavior on color { ColorAnimation { duration: 150 } } }
                                    MouseArea { id: prevMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "previous"]); musicForceRefresh.running = true; } }
                                }
                                Item {
                                    width: barWindow.s(24); height: barWindow.s(24); anchors.verticalCenter: parent.verticalCenter
                                    Text { anchors.centerIn: parent; text: barWindow.musicData.status === "Playing" ? "󰏤" : "󰐊"; font.family: barWindow.iconFont; font.pixelSize: barWindow.s(26); color: playMouse.containsMouse ? mocha.green : mocha.text; Behavior on color { ColorAnimation { duration: 150 } } }
                                    MouseArea { id: playMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "play-pause"]); musicForceRefresh.running = true; } }
                                }
                                Item {
                                    width: barWindow.s(20); height: barWindow.s(20); anchors.verticalCenter: parent.verticalCenter
                                    Text { anchors.centerIn: parent; text: "󰒭"; font.family: barWindow.iconFont; font.pixelSize: barWindow.s(22); color: nextMouse.containsMouse ? mocha.text : mocha.overlay2; Behavior on color { ColorAnimation { duration: 150 } } }
                                    MouseArea { id: nextMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "next"]); musicForceRefresh.running = true; } }
                                }
                            }
                        }
                    }

                    // System Elements Pill
                    Rectangle {
                        height: barWindow.barHeight
                        radius: height / 2
                        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                        border.width: 1
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        clip: true
                        
                        property real targetWidth: sysLayout.width + barWindow.s(20)
                        width: targetWidth
                        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                        Row {
                            id: sysLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(8) 

                            property int pillHeight: barWindow.s(34)

                            // KB
                            Rectangle {
                                property bool isHovered: kbMouse.containsMouse
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                                radius: height / 2; height: sysLayout.pillHeight;
                                clip: true
                                
                                property real targetWidth: kbLayoutRow.width + barWindow.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                                
                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !parent.initAnimTrigger; interval: 0; onTriggered: parent.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: parent.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: kbLayoutRow; anchors.centerIn: parent; spacing: barWindow.s(8)
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "󰌌"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(16); color: parent.parent.isHovered ? mocha.text : mocha.overlay2 }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: barWindow.kbLayout; font.family: barWindow.textFont; font.pixelSize: barWindow.s(13); font.weight: Font.Black; color: mocha.text }
                                }
                                MouseArea { id: kbMouse; anchors.fill: parent; hoverEnabled: true; onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]) }
                            }

                            // WiFi / Ethernet (Desktop Mode)
                            Rectangle {
                                id: wifiPill
                                property bool isHovered: wifiMouse.containsMouse
                                radius: height / 2; height: sysLayout.pillHeight; 
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                                clip: true
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    opacity: barWindow.showEthernet ? (barWindow.ethStatus === "Connected" ? 1.0 : 0.0) : (barWindow.isWifiOn ? 1.0 : 0.0)
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: sysConfig.accent }
                                        GradientStop { position: 1.0; color: Qt.lighter(sysConfig.accent, 1.3) }
                                    }
                                }

                                property real targetWidth: wifiLayoutRow.width + barWindow.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                                
                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !parent.initAnimTrigger; interval: 50; onTriggered: parent.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: parent.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: wifiLayoutRow; anchors.centerIn: parent; spacing: barWindow.s(8)
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter; 
                                        text: barWindow.showEthernet ? "󰈀" : barWindow.wifiIcon;
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(16);
                                        color: barWindow.showEthernet ? (barWindow.ethStatus === "Connected" ? mocha.base : mocha.subtext0) : (barWindow.isWifiOn ? mocha.base : mocha.subtext0)
                                    }
                                    Text { 
                                        id: wifiText
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.showEthernet ? barWindow.ethStatus : ((barWindow.isWifiOn ? (barWindow.wifiSsid !== "" ? barWindow.wifiSsid : "On") : "Off"))
                                        visible: text !== ""
                                        font.family: barWindow.textFont; font.pixelSize: barWindow.s(13); font.weight: Font.Black;
                                        color: barWindow.showEthernet ? (barWindow.ethStatus === "Connected" ? mocha.base : mocha.text) : (barWindow.isWifiOn ? mocha.base : mocha.text);
                                        width: Math.min(implicitWidth, barWindow.s(100)); elide: Text.ElideRight 
                                    }
                                }
                                MouseArea { id: wifiMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/quickshell/qs_manager.sh toggle network wifi"]) }
                            }

                            // Bluetooth
                            Rectangle {
                                id: btPill
                                property bool isHovered: btMouse.containsMouse
                                radius: height / 2; height: sysLayout.pillHeight
                                clip: true
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    opacity: barWindow.isBtOn ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: mocha.mauve }
                                        GradientStop { position: 1.0; color: Qt.lighter(mocha.mauve, 1.3) }
                                    }
                                }

                                property real targetWidth: barWindow.isDesktop ? 0 : btLayoutRow.width + barWindow.s(24)
                                width: targetWidth
                                visible: targetWidth > 0
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !parent.initAnimTrigger; interval: 100; onTriggered: parent.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: parent.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: btLayoutRow; anchors.centerIn: parent; spacing: barWindow.s(8)
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: barWindow.btIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(16); color: barWindow.isBtOn ? mocha.base : mocha.subtext0 }
                                    Text { 
                                        id: btText
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.btDevice
                                        visible: text !== "";
                                        font.family: barWindow.textFont; font.pixelSize: barWindow.s(13); font.weight: Font.Black;
                                        color: barWindow.isBtOn ? mocha.base : mocha.text; 
                                        width: Math.min(implicitWidth, barWindow.s(100)); elide: Text.ElideRight 
                                    }
                                }
                                MouseArea { id: btMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/quickshell/qs_manager.sh toggle network bt"]) }
                            }

                            // Volume
                            Rectangle {
                                property bool isHovered: volMouse.containsMouse
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                                radius: height / 2; height: sysLayout.pillHeight;
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    opacity: barWindow.isSoundActive ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: sysConfig.accent }
                                        GradientStop { position: 1.0; color: Qt.lighter(sysConfig.accent, 1.3) }
                                    }
                                }
                                
                                property real targetWidth: volLayoutRow.width + barWindow.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                                
                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !parent.initAnimTrigger; interval: 150; onTriggered: parent.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: parent.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: volLayoutRow; anchors.centerIn: parent; spacing: barWindow.s(8)
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.volIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(16); 
                                        color: barWindow.isSoundActive ? mocha.base : mocha.subtext0 
                                    }
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.volPercent;
                                        font.family: barWindow.textFont; font.pixelSize: barWindow.s(13); font.weight: Font.Black;
                                        color: barWindow.isSoundActive ? mocha.base : mocha.text; 
                                    }
                                }
                                MouseArea { id: volMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/quickshell/qs_manager.sh toggle volume"]) }
                            }

                            // Battery pill (laptop only)
                            Rectangle {
                                property bool isHovered: batMouse.containsMouse
                                visible: sysConfig.isLaptop
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4); 
                                radius: height / 2; height: sysLayout.pillHeight;
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    opacity: 1.0 
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: barWindow.batDynamicColor; Behavior on color { ColorAnimation { duration: 300 } } }
                                        GradientStop { position: 1.0; color: Qt.lighter(barWindow.batDynamicColor, 1.3); Behavior on color { ColorAnimation { duration: 300 } } }
                                    }
                                }
                                
                                property real targetWidth: batLayoutRow.width + barWindow.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !parent.initAnimTrigger; interval: 200; onTriggered: parent.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: parent.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row {
                                    id: batLayoutRow; anchors.centerIn: parent; spacing: barWindow.s(8)
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.batIcon
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(16)
                                        color: mocha.base
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.batPercent; font.family: barWindow.textFont; font.pixelSize: barWindow.s(13); font.weight: Font.Black
                                        color: mocha.base
                                    }
                                }
                                MouseArea { id: batMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/quickshell/qs_manager.sh toggle battery"]) }
                            }

                            // Power button (always visible)
                            Rectangle {
                                property bool isHovered: pwrMouse.containsMouse
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                                radius: height / 2; height: sysLayout.pillHeight
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    opacity: 1.0
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: sysConfig.accent }
                                        GradientStop { position: 1.0; color: Qt.lighter(sysConfig.accent, 1.3) }
                                    }
                                }

                                width: barWindow.s(34)

                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !parent.initAnimTrigger; interval: sysConfig.isLaptop ? 250 : 200; onTriggered: parent.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: parent.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(18)
                                    color: mocha.base
                                }
                                MouseArea { id: pwrMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/quickshell/qs_manager.sh toggle battery"]) }
                            }
                        }
                    }
                    
                    // --- Screen Recording Indicator & Stop Button ---
                    Rectangle {
                        id: recButton
                        property bool isHovered: recMouse.containsMouse
                        
                        color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.95) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        radius: height / 2
                        border.width: 1
                        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, isHovered ? 0.15 : 0.05)

                        property real targetWidth: barWindow.isRecording ? barWindow.barHeight : 0
                        width: targetWidth
                        height: barWindow.barHeight 

                        visible: targetWidth > 0 || opacity > 0
                        opacity: barWindow.isRecording ? 1.0 : 0.0
                        clip: true

                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        
                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            id: recIcon
                            anchors.centerIn: parent
                            text: "" 
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: barWindow.s(20)
                            color: mocha.red
                            
                            SequentialAnimation on opacity {
                                running: barWindow.isRecording && !recButton.isHovered
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                            SequentialAnimation on scale {
                                running: barWindow.isRecording && !recButton.isHovered
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.15; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }
                        
                        MouseArea {
                            id: recMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                barWindow.isRecording = false; 
                                Quickshell.execDetached(["bash", "-c", "~/.config/quickshell/screenshot.sh"]); 
                            }
                        }
                    }                   
                }
            }
        }
    }
}
