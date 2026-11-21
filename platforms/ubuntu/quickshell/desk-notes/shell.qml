// Desk notes: every ~/.config/desk-notes/<name>.md becomes a Markdown card on the desktop, behind windows.
// <name>.json places it in pixels from screen edges, e.g. {"top": 62, "right": 28}; without it the card sits top right.
// The files stay out of this public repo; saving or adding one updates the cards.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // Lines up with the window gaps below Caelestia's top bar.
    readonly property var defaultPlace: ({ top: 62, right: 28 })

    FolderListModel {
        id: notes
        folder: "file://" + Quickshell.env("HOME") + "/.config/desk-notes"
        nameFilters: ["*.md"]
        showDirs: false
    }

    Instantiator {
        model: notes

        PanelWindow {
            id: note
            required property string filePath
            property string body: ""
            property var place: root.defaultPlace

            visible: body.trim() !== ""
            anchors.top: place.top !== undefined
            anchors.bottom: place.bottom !== undefined
            anchors.left: place.left !== undefined
            anchors.right: place.right !== undefined
            margins.top: place.top ?? 0
            margins.bottom: place.bottom ?? 0
            margins.left: place.left ?? 0
            margins.right: place.right ?? 0
            implicitWidth: card.width
            implicitHeight: card.height
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "desk-notes"
            mask: Region {}

            FileView {
                path: note.filePath
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: note.body = text()
                onLoadFailed: note.body = ""
            }

            FileView {
                path: note.filePath.replace(/\.md$/, ".json")
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: {
                    try {
                        note.place = JSON.parse(text());
                    } catch (error) {
                        console.warn("desk-notes: " + path + ": " + error);
                        note.place = root.defaultPlace;
                    }
                }
                onLoadFailed: note.place = root.defaultPlace
            }

            Rectangle {
                id: card
                width: column.width + 36
                height: column.height + 28
                radius: 12
                color: "#b3101014"
                border.color: "#40ffffff"

                Column {
                    id: column
                    anchors.centerIn: parent

                    // Replacing a MarkdownText's text squeezes the gaps between blocks,
                    // so each version of the file gets a fresh Text.
                    Repeater {
                        model: [note.body]

                        Text {
                            required property string modelData
                            width: Math.min(implicitWidth, 420)
                            text: modelData
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
        }
    }
}
