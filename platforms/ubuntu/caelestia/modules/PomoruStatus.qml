import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property var snapshot: ({})
    property bool running: false
    readonly property string remaining: String(snapshot.text ?? "").match(/\d+:\d+(?::\d+)?/)?.[0] ?? ""
    readonly property bool available: running && remaining.length > 0
    readonly property bool working: snapshot.class === "work"
    readonly property string description: snapshot.tooltip ?? "Pomoru"

    FileView {
        id: status
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/pomoru/status.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            // Pomoru truncates then writes this file; retain the last complete snapshot.
            try {
                const value = JSON.parse(text());
                if (typeof value.text === "string" && typeof value.class === "string")
                    root.snapshot = value;
            } catch (error) {}
        }
        // Missing/transient files retain the last value until the process check clears it.
        onLoadFailed: {}
    }

    // Also clear stale status left behind by an abruptly closed terminal.
    Process {
        id: checkProcess
        command: ["pgrep", "-x", "pomoru"]
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => root.running = exitCode === 0
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!checkProcess.running) checkProcess.running = true; }
    }
    // Reopen after deletion/recreation and retry a partially written JSON file.
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: status.reload()
    }
}
