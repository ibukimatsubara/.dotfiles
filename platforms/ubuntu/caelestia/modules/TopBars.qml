pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Services
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.modules.bar.components as BarComponents
import qs.services
import qs.utils
import "Layout.js" as BarLayout

Variants {
    model: Screens.screens

    StyledWindow {
        id: bar

        required property ShellScreen modelData
        readonly property var monitor: Hypr.monitorFor(modelData)
        readonly property int activeWorkspace: monitor?.activeWorkspace?.id ?? 1
        readonly property int workspaceCount: GlobalConfig.forScreen(modelData.name).bar.workspaces.shown
        readonly property int workspaceOffset: Math.floor((activeWorkspace - 1) / workspaceCount) * workspaceCount
        readonly property bool fullscreen: (monitor?.activeWorkspace?.lastIpcObject?.hasfullscreen ?? false)

        ServiceRef { service: Cpu }
        ServiceRef { service: Memory }
        ServiceRef { service: Storage }
        property var codexSnapshot: ({})
        PomoruStatus { id: pomoru }
        Timer {
            interval: 2000
            running: true
            onTriggered: Weather.reload()
        }
        Timer {
            interval: 60000
            running: true
            repeat: true
            onTriggered: {
                if (!Weather.cc) {
                    Weather.reload();
                    Weather.fetchWeatherData();
                }
            }
        }

        Process {
            id: codexPoll
            command: ["python3", Quickshell.env("HOME") + "/.dotfiles/scripts/codex-usage.py"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try { bar.codexSnapshot = JSON.parse(text); }
                    catch (error) { bar.codexSnapshot = {}; }
                }
            }
        }
        Timer {
            interval: 60000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: { if (!codexPoll.running) codexPoll.running = true; }
        }

        function toggleDrawer(name: string): void {
            const drawers = Visibilities.screens.get(monitor);
            if (drawers)
                drawers[name] = !drawers[name];
        }

        name: "topbar"
        screen: modelData
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: BarLayout.height
        exclusionMode: ExclusionMode.Ignore
        visible: !fullscreen

        // Reserve app space separately so the bar can cover the frame's inset.
        StyledWindow {
            name: "topbar-exclusion"
            screen: bar.screen
            anchors.top: true
            anchors.left: true
            anchors.right: true
            implicitHeight: 1
            exclusiveZone: BarLayout.height
            mask: Region {}
            visible: bar.visible
        }

        StyledRect {
            anchors.fill: parent
            color: Colours.palette.m3surface

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                RowLayout {
                    id: leftSection
                    spacing: 10
                    BarComponents.OsIcon {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                    }

                    Metric {
                        visible: pomoru.available
                        icon: pomoru.working ? "" : "coffee"
                        tomatoIcon: pomoru.working
                        fixedDigits: true
                        label: pomoru.remaining
                        detail: "Pomoru · " + pomoru.description
                        foreground: pomoru.working ? "#b49cde" : Colours.palette.m3onSurfaceVariant
                    }

                    StyledRect {
                        Layout.preferredWidth: workspaceRow.implicitWidth + 8
                        Layout.preferredHeight: 32
                        radius: 16
                        color: Colours.palette.m3surfaceContainer

                        Row {
                            id: workspaceRow
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: bar.workspaceCount

                                StyledRect {
                                    id: workspace
                                    required property int index
                                    readonly property int number: bar.workspaceOffset + index + 1
                                    readonly property bool selected: bar.activeWorkspace === number
                                    readonly property bool occupied: Hypr.workspaces.values.some(w => w.id === number && w.lastIpcObject.windows > 0)
                                    readonly property var windows: {
                                        const config = GlobalConfig.forScreen(bar.modelData.name).bar.workspaces;
                                        if (!config.showWindows)
                                            return [];
                                        const all = Hypr.toplevels.values.filter(w => w.workspace?.id === number);
                                        return config.maxWindowIcons > 0 ? all.slice(0, config.maxWindowIcons) : all;
                                    }

                                    width: Math.max(30, workspaceContents.implicitWidth + 16)
                                    height: 26
                                    radius: 13
                                    color: selected ? Colours.palette.m3primary : hit.containsMouse ? Colours.palette.m3surfaceContainerHigh : "transparent"

                                    Row {
                                        id: workspaceContents
                                        anchors.centerIn: parent
                                        spacing: 4

                                        StyledText {
                                            width: 14
                                            height: 20
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            text: workspace.number
                                            font.family: Tokens.font.workspaces
                                            font.bold: workspace.selected || workspace.occupied
                                            color: workspace.selected ? Colours.palette.m3onPrimary : workspace.occupied ? Colours.palette.m3onSurface : Colours.palette.m3outline
                                        }

                                        Repeater {
                                            model: ScriptModel { values: workspace.windows }
                                            MaterialIcon {
                                                required property var modelData
                                                width: 18
                                                height: 20
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "apps")
                                                color: workspace.selected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: hit
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Hypr.dispatch(`workspace ${workspace.number}`)
                                        onWheel: event => Hypr.dispatch(`workspace e${event.angleDelta.y > 0 ? "-1" : "+1"}`)
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    id: rightSection
                    Layout.alignment: Qt.AlignRight
                    Layout.maximumWidth: implicitWidth
                    spacing: 10
                    Metric {
                        icon: "terminal"
                        label: bar.codexSnapshot.available ? bar.codexSnapshot.label : "--"
                        detail: "Codex remaining\n" + (bar.codexSnapshot.tooltip ?? "Usage unavailable")
                    }
                    Metric { icon: "memory"; label: Math.round(Cpu.percentage * 100) + "%"; detail: "CPU usage" }
                    Metric { icon: "memory_alt"; label: Math.round(Memory.percentage * 100) + "%"; detail: "Memory usage" }
                    Metric { icon: "hard_disk"; label: Math.round((Storage.primaryDisk?.perc ?? 0) * 100) + "%"; detail: "System SSD storage used" }
                    Metric {
                        icon: Weather.icon
                        label: Weather.temp
                        detail: Weather.city + " · " + Weather.description + "\nFeels like " + Weather.feelsLike + " · Humidity " + Weather.humidity + "%"
                        onClicked: bar.toggleDrawer("dashboard")
                    }

                    RowLayout {
                        visible: GlobalConfig.forScreen(bar.modelData.name).bar.entries.some(entry => entry.id === "tray" && entry.enabled)
                        Layout.maximumWidth: implicitWidth
                        spacing: 10
                        Repeater {
                            model: ScriptModel {
                                values: SystemTray.items.values.filter(item => !GlobalConfig.bar.tray.hiddenIcons.includes(item.id))
                            }
                            MouseArea {
                                id: tray
                                required property SystemTrayItem modelData
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: event => {
                                    if (event.button === Qt.RightButton || modelData.onlyMenu) {
                                        const point = mapToItem(bar.contentItem, 0, height);
                                        modelData.display(bar, point.x, bar.height);
                                    } else if (event.button === Qt.MiddleButton) {
                                        modelData.secondaryActivate();
                                    } else {
                                        modelData.activate();
                                    }
                                }
                                Image {
                                    anchors.fill: parent
                                    source: Icons.getTrayIcon(tray.modelData.id, tray.modelData.icon)
                                    fillMode: Image.PreserveAspectFit
                                }
                            }
                        }
                    }

                    BarButton {
                        icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                        onClicked: bar.toggleDrawer("osd")
                        onScrolled: delta => delta > 0 ? Audio.incrementVolume() : Audio.decrementVolume()
                    }
                    BarButton {
                        icon: Nmcli.activeEthernet ? "cable" : Nmcli.active ? Icons.getNetworkIcon(Nmcli.active.strength ?? 0) : "wifi_off"
                        onClicked: Quickshell.execDetached(["caelestia", "shell", "nexus", "open"])
                    }
                    BarButton {
                        visible: UPower.displayDevice.isLaptopBattery
                        icon: Icons.getBatteryIcon(UPower.displayDevice.percentage, !UPower.onBattery)
                        onClicked: bar.toggleDrawer("dashboard")
                    }
                    BarButton {
                        icon: "notifications"
                        onClicked: bar.toggleDrawer("sidebar")
                    }
                    StyledText {
                        Layout.leftMargin: 6
                        Layout.rightMargin: 6
                        text: Time.format("ddd d  HH:mm")
                        color: Colours.palette.m3onSurfaceVariant
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bar.toggleDrawer("dashboard")
                        }
                    }
                    BarButton {
                        icon: "power_settings_new"
                        onClicked: bar.toggleDrawer("session")
                    }
                }
            }

            NowPlaying {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                // Keep the media truly centered without overlapping either side.
                width: Math.max(0, Math.min(360, parent.width - 2 * (Math.max(leftSection.implicitWidth, rightSection.implicitWidth) + 26)))
                visible: available && width >= 120
            }
        }
    }

    component Metric: StyledRect {
        id: metric
        required property string icon
        required property string label
        required property string detail
        property color foreground: Colours.palette.m3onSurfaceVariant
        property bool tomatoIcon: false
        property bool fixedDigits: false
        signal clicked
        implicitWidth: contents.implicitWidth + 12
        implicitHeight: 30
        radius: 10
        color: hover.containsMouse ? Colours.palette.m3surfaceContainerHigh : "transparent"
        RowLayout {
            id: contents
            anchors.centerIn: parent
            spacing: metric.icon.length > 0 || metric.tomatoIcon ? 5 : 0
            TomatoIcon {
                visible: metric.tomatoIcon
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
            }
            MaterialIcon {
                visible: metric.icon.length > 0
                Layout.alignment: Qt.AlignVCenter
                text: metric.icon
                color: metric.foreground
            }
            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: metric.fixedDigits ? 52 : implicitWidth
                Layout.preferredHeight: 24
                verticalAlignment: Text.AlignVCenter
                font: metric.fixedDigits ? Qt.font({ family: "Hack Nerd Font Mono", pointSize: Tokens.font.body.small.pointSize }) : Tokens.font.body.small
                text: metric.label
                color: metric.foreground
            }
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: metric.clicked()
        }
        ToolTip.visible: hover.containsMouse
        ToolTip.delay: 500
        ToolTip.text: detail
    }

    component BarButton: StyledRect {
        id: button
        required property string icon
        signal clicked
        signal scrolled(real delta)

        implicitWidth: 30
        implicitHeight: 30
        radius: 15
        color: mouse.containsMouse ? Colours.palette.m3surfaceContainerHigh : "transparent"

        MaterialIcon {
            anchors.centerIn: parent
            text: button.icon
            color: Colours.palette.m3onSurfaceVariant
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
            onWheel: event => button.scrolled(event.angleDelta.y)
        }
    }
}
