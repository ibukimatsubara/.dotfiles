import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    property var snapshot: ({label: "--", tooltip: "Waiting for local status"})
    Process {
        id: poll
        command: ["python3", Quickshell.env("HOME") + "/.dotfiles/scripts/ubuntu-break-timer.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.snapshot = JSON.parse(this.text); }
                catch (error) { root.snapshot = {label: "--", tooltip: "Local status unavailable"}; }
            }
        }
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!poll.running) poll.running = true }

    function act(action) {
        if (actionProcess.running) return;
        actionProcess.command = ["python3", Quickshell.env("HOME") + "/.dotfiles/scripts/ubuntu-break-timer.py", action];
        actionProcess.running = true;
    }
    Process { id: actionProcess; onExited: poll.running = true }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            DankIcon { name: "timer"; size: root.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: root.snapshot.label || "--"; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    verticalBarPill: Component {
        StyledText { text: root.snapshot.label || "--"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
    }
    popoutWidth: 400
    popoutHeight: 240
    popoutContent: Component {
        PopoutComponent {
            headerText: "Break timer"
            showCloseButton: true
            Column {
                width: parent.width
                spacing: Theme.spacingM
                StyledText { width: parent.width; text: root.snapshot.tooltip || "No local data"; wrapMode: Text.Wrap; color: Theme.surfaceText }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingS
                    Repeater {
                        model: [{label: "Work", action: "start-work"}, {label: "Break", action: "start-break"}, {label: "Snooze", action: "snooze"}, {label: "Stop", action: "stop"}]
                        delegate: Rectangle {
                            required property var modelData
                            width: 76; height: 36; radius: Theme.cornerRadius
                            color: mouse.containsMouse ? Theme.primary : Theme.surfaceContainerHigh
                            StyledText { anchors.centerIn: parent; text: modelData.label; color: mouse.containsMouse ? Theme.primaryText : Theme.surfaceText }
                            MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.act(modelData.action) }
                        }
                    }
                }

            }
        }
    }
}
