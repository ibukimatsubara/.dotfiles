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
        command: ["python3", Quickshell.env("HOME") + "/.dotfiles/scripts/codex-usage.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.snapshot = JSON.parse(this.text); }
                catch (error) { root.snapshot = {label: "--", tooltip: "Local status unavailable"}; }
            }
        }
    }
    Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!poll.running) poll.running = true }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            DankIcon { name: "data_usage"; size: root.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: root.snapshot.label || "--"; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    verticalBarPill: Component {
        StyledText { text: root.snapshot.label || "--"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
    }
    popoutWidth: 400
    popoutHeight: 300
    popoutContent: Component {
        PopoutComponent {
            headerText: "Codex usage"
            showCloseButton: true
            Column {
                width: parent.width
                spacing: Theme.spacingM
                StyledText { width: parent.width; text: root.snapshot.tooltip || "No local data"; wrapMode: Text.Wrap; color: Theme.surfaceText }

            }
        }
    }
}
