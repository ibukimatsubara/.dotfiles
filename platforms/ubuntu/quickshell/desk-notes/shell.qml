// Desk notes: every ~/.config/desk-notes/<name>.md becomes a Markdown card on the desktop, behind windows,
// and every <name>.png/.jpg/.webp a sticker. <name>.json places it in pixels from screen edges, e.g.
// {"top": 62, "right": 28}; "width" sizes a card or sticker and "fontSize" a card's text. Without the JSON it
// sits top right. The files stay out of this public repo; saving or adding one updates the desktop.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    // A reload pops "Config reloaded" over the windows; restart the widget to pick up edits instead.
    settings.watchFiles: false

    // Lines up with the window gaps below Caelestia's top bar.
    readonly property var defaultPlace: ({ top: 62, right: 28 })
    property var files: []

    function parsePlace(json) {
        const place = JSON.parse(json);
        const edges = ["top", "bottom", "left", "right"];
        if (place === null || typeof place !== "object" || Array.isArray(place)
                || edges.some(edge => edge in place && !Number.isFinite(place[edge]))
                || ("top" in place && "bottom" in place) || ("left" in place && "right" in place)
                || ["width", "fontSize"].some(size => size in place && !(Number.isFinite(place[size]) && place[size] > 0)))
            throw new Error('expected numbers such as {"top": 62, "right": 28, "width": 240, "fontSize": 19}');
        return place;
    }

    FolderListModel {
        id: notes
        folder: "file://" + Quickshell.env("HOME") + "/.config/desk-notes"
        nameFilters: ["*.md", "*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
        // Variants keeps the cards whose paths stay listed, so feed it only finished listings.
        onStatusChanged: {
            if (status === FolderListModel.Ready)
                root.files = Array.from({ length: count }, (_, i) => get(i, "filePath"));
        }
    }

    Variants {
        model: root.files

        PanelWindow {
            id: note
            required property string modelData
            readonly property string filePath: modelData
            readonly property bool isImage: !filePath.endsWith(".md")
            property string body: ""
            property var place: root.defaultPlace

            visible: isImage ? picture.status === Image.Ready : body.trim() !== ""
            anchors.top: place.top !== undefined
            anchors.bottom: place.bottom !== undefined
            anchors.left: place.left !== undefined
            anchors.right: place.right !== undefined
            margins.top: place.top ?? 0
            margins.bottom: place.bottom ?? 0
            margins.left: place.left ?? 0
            margins.right: place.right ?? 0
            implicitWidth: isImage ? picture.width : card.width
            implicitHeight: isImage ? picture.height : card.height
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "desk-notes"
            mask: Region {}

            FileView {
                path: note.isImage ? "" : note.filePath
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: note.body = text()
                onLoadFailed: note.body = ""
            }

            FileView {
                path: note.filePath.replace(/\.[^.]+$/, ".json")
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: {
                    try {
                        note.place = root.parsePlace(text());
                    } catch (error) {
                        console.warn("desk-notes: " + path + ": " + error);
                        note.place = root.defaultPlace;
                    }
                }
                onLoadFailed: note.place = root.defaultPlace
            }

            Image {
                id: picture
                visible: note.isImage
                source: note.isImage ? "file://" + note.filePath : ""
                width: note.place.width ?? 240
                height: implicitWidth > 0 ? width * implicitHeight / implicitWidth : 0
                sourceSize.width: width
                cache: false
            }

            Rectangle {
                id: card
                visible: !note.isImage
                width: note.place.width ?? column.width + 36
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
                            width: note.place.width ? note.place.width - 36 : Math.min(implicitWidth, 420)
                            text: modelData
                            textFormat: Text.MarkdownText
                            wrapMode: Text.Wrap
                            color: "white"
                            font.pixelSize: note.place.fontSize ?? 19
                            font.weight: Font.DemiBold
                            lineHeight: 1.15
                        }
                    }
                }
            }
        }
    }
}
