// Keycast: shows the last three key presses, clicks and wheel turns at the bottom right of each screen.
// The desktop shell starts this instance; scripts/ubuntu-keycast.sh toggles it. Input comes from scripts/keycast-events.py.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool enabled: true

    ListModel { id: entries }

    function reset() {
        entries.clear();
        clear.stop();
    }

    function add(event) {
        const now = Date.now();
        const last = entries.count ? entries.get(entries.count - 1) : null;
        const recent = last && now - last.at < 1000;
        // Letters, digits and symbols typed alone; ⌫, Space and shortcuts are separate rows.
        const word = event.text.length === 1 && event.text !== "⌫";
        if (recent && word && last.word) {
            // Plain typing joins into one row; only its tail is shown.
            entries.setProperty(entries.count - 1, "text", (last.text + event.text).slice(-12));
        } else if (recent && last.text === event.text) {
            // Repeats of the same key within a second become one "×N" row.
            entries.setProperty(entries.count - 1, "count", last.count + 1);
        } else {
            entries.append({ text: event.text, time: event.time, count: 1, at: now, word: word });
            if (entries.count > 3)
                entries.remove(0);
            return clear.restart();
        }
        entries.setProperty(entries.count - 1, "time", event.time);
        entries.setProperty(entries.count - 1, "at", now);
        clear.restart();
    }

    onEnabledChanged: {
        if (!enabled)
            reset();
    }

    IpcHandler {
        target: "keycast"

        function toggle(): string {
            root.enabled = !root.enabled;
            return root.enabled ? "shown" : "hidden";
        }

        function status(): string {
            return root.enabled ? "shown" : "hidden";
        }
    }

    Timer {
        id: clear
        interval: 4000
        onTriggered: entries.clear()
    }

    Process {
        running: root.enabled
        command: ["python3", Quickshell.env("HOME") + "/.dotfiles/scripts/keycast-events.py"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line);
                    if (event.clear === true)
                        root.reset();
                    else
                        root.add(event);
                } catch (error) {
                    console.warn("keycast: " + line);
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.enabled
            anchors.bottom: true
            anchors.right: true
            margins.bottom: 16
            margins.right: 16
            implicitWidth: column.implicitWidth
            implicitHeight: Math.max(1, column.implicitHeight)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "keycast"
            // Clicks pass through to the windows underneath.
            mask: Region {}

            Column {
                id: column
                spacing: 4

                Repeater {
                    model: entries

                    Rectangle {
                        required property string text
                        required property string time
                        required property int count
                        anchors.right: parent.right
                        width: row.implicitWidth + 18
                        height: 28
                        radius: 7
                        color: "#d9101014"
                        border.color: "#40ffffff"

                        Row {
                            id: row
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: parent.parent.text + (parent.parent.count > 1 ? "  ×" + parent.parent.count : "")
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.parent.time
                                color: "#b0b0b8"
                                font.pixelSize: 10
                                font.family: "monospace"
                            }
                        }
                    }
                }
            }
        }
    }
}
