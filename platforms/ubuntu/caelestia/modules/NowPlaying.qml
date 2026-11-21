pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.services

StyledRect {
    id: root

    // Prefer a playing track with metadata, then any player with metadata, then the active fallback.
    readonly property var player: Players.list.find(p => p.isPlaying && (p.trackTitle ?? "").length > 0)
        ?? Players.list.find(p => (p.trackTitle ?? "").length > 0)
        ?? Players.active
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string artwork: Players.getArtUrl(player)
    readonly property bool available: player !== null && title.length > 0
    readonly property string uiFont: "Inter"
    readonly property real naturalTextWidth: titleMetrics.advanceWidth + (artist.length > 0 ? sepMetrics.advanceWidth + artistMetrics.advanceWidth + 10 : 0)
    // 6px left margin + 20px cover + 8px gap + text + 12px right margin
    readonly property real preferredWidth: Math.min(320, Math.max(120, Math.ceil(naturalTextWidth) + 48))

    TextMetrics {
        id: titleMetrics
        font.family: root.uiFont
        font.pixelSize: 12
        font.weight: Font.Medium
        text: root.title
    }
    TextMetrics {
        id: sepMetrics
        font.family: root.uiFont
        font.pixelSize: 12
        font.weight: Font.Medium
        text: "·"
    }
    TextMetrics {
        id: artistMetrics
        font.family: root.uiFont
        font.pixelSize: 12
        font.weight: Font.Normal
        text: root.artist
    }

    implicitWidth: preferredWidth
    implicitHeight: 30
    radius: 10
    color: hover.containsMouse ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3surfaceContainer
    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, hover.containsMouse ? 0.45 : 0.28)

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 10
        spacing: 8

        StyledClippingRect {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            radius: 5

            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("media-placeholder.png")
                sourceSize.width: 40
                sourceSize.height: 40
                fillMode: Image.PreserveAspectCrop
                visible: cover.status !== Image.Ready
            }
            Image {
                id: cover
                anchors.fill: parent
                source: root.artwork
                sourceSize.width: 40
                sourceSize.height: 40
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 5

            StyledText {
                Layout.fillWidth: true
                Layout.maximumWidth: Math.ceil(titleMetrics.advanceWidth) + 2
                Layout.minimumWidth: 48
                text: root.title
                color: Colours.palette.m3onSurface
                font.family: root.uiFont
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
            }

            StyledText {
                visible: root.artist.length > 0
                text: "·"
                color: Colours.palette.m3outline
                font.family: root.uiFont
                font.pixelSize: 12
                font.weight: Font.Medium
                textFormat: Text.PlainText
            }

            StyledText {
                visible: root.artist.length > 0
                Layout.fillWidth: true
                Layout.maximumWidth: Math.ceil(artistMetrics.advanceWidth) + 2
                text: root.artist
                color: Colours.palette.m3onSurfaceVariant
                font.family: root.uiFont
                font.pixelSize: 12
                font.weight: Font.Normal
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
            }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.player?.canTogglePlaying ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.player?.canTogglePlaying)
                root.player.togglePlaying();
        }
    }
    ToolTip.visible: hover.containsMouse
    ToolTip.delay: 500
    ToolTip.text: root.title + (root.artist ? "\n" + root.artist : "") + "\n" + (root.player?.isPlaying ? qsTr("Playing · Click to pause") : qsTr("Paused · Click to play"))
}
