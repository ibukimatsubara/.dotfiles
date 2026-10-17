pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.services

StyledRect {
    id: root

    // Prefer a player actually playing over an idle browser or paused player.
    readonly property var player: Players.list.find(p => p.isPlaying) ?? Players.active
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string artwork: Players.getArtUrl(player)
    readonly property bool available: player !== null && title.length > 0

    implicitHeight: 32
    radius: 10
    color: hover.containsMouse ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3surfaceContainer

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 7
        anchors.rightMargin: 8
        spacing: 7

        StyledClippingRect {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            radius: 6

            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("media-placeholder.png")
                sourceSize.width: 48
                sourceSize.height: 48
                fillMode: Image.PreserveAspectCrop
                visible: cover.status !== Image.Ready
            }
            Image {
                id: cover
                anchors.fill: parent
                source: root.artwork
                sourceSize.width: 48
                sourceSize.height: 48
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.artist ? root.title + " · " + root.artist : root.title
            color: Colours.palette.m3onSurface
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
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
