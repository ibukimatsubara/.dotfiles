// Desk notes: shows ~/.config/desk-notes/notes.md (Markdown) on the desktop, behind windows.
// The text stays out of this public repo; saving the file updates the card.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property string notes: ""

    FileView {
        path: Quickshell.env("HOME") + "/.config/desk-notes/notes.md"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.notes = text()
        onLoadFailed: root.notes = ""
    }

    PanelWindow {
        visible: root.notes.trim() !== ""
        anchors.top: true
        anchors.right: true
        // Line up with the window gaps below Caelestia's top bar.
        margins.top: 62
        margins.right: 28
        implicitWidth: card.width
        implicitHeight: card.height
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "desk-notes"
        mask: Region {}

        Rectangle {
            id: card
            width: body.width + 36
            height: body.height + 28
            radius: 12
            color: "#b3101014"
            border.color: "#40ffffff"

            Text {
                id: body
                anchors.centerIn: parent
                width: Math.min(implicitWidth, 420)
                text: root.notes
                textFormat: Text.MarkdownText
                wrapMode: Text.Wrap
                color: "white"
                font.pixelSize: 19
                font.weight: Font.DemiBold
                lineHeight: 1.15
            }
        }
    }
}
