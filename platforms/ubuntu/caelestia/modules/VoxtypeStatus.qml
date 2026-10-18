import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    property string phase: "stopped"
    readonly property bool recording: phase === "recording" || phase === "streaming"
    readonly property bool available: recording || phase === "transcribing"
    property double startedAt: 0
    property int elapsedSeconds: 0
    readonly property string icon: recording ? "mic" : "hourglass_top"
    readonly property string label: recording
        ? "REC " + String(Math.floor(elapsedSeconds / 60)).padStart(2, "0") + ":" + String(elapsedSeconds % 60).padStart(2, "0")
        : "Processing…"
    readonly property string description: recording
        ? "Voxtype · Recording\nShift+Space to stop"
        : "Voxtype · Transcribing"

    onRecordingChanged: {
        startedAt = recording ? Date.now() : 0;
        elapsedSeconds = 0;
    }

    // The native watcher also detects daemon exits and ignores stale state files.
    Process {
        id: status
        command: ["voxtype", "status", "--follow", "--format", "json"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data);
                    // Ignore partial writes rather than briefly hiding an active recording.
                    if (["idle", "stopped", "recording", "streaming", "transcribing"].includes(value.class))
                        root.phase = value.class;
                } catch (error) {}
            }
        }
        onRunningChanged: {
            if (!running)
                root.phase = "stopped";
        }
    }
    Timer {
        interval: 5000
        running: !status.running
        repeat: true
        onTriggered: status.running = true
    }
    Timer {
        interval: 250
        running: root.recording
        repeat: true
        onTriggered: root.elapsedSeconds = Math.max(0, Math.floor((Date.now() - root.startedAt) / 1000))
    }
}
