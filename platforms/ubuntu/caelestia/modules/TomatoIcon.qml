import QtQuick
import QtQuick.Shapes

Item {
    implicitWidth: 16
    implicitHeight: 16
    Shape {
        width: 24
        height: 24
        scale: parent.width / 24
        transformOrigin: Item.TopLeft
        ShapePath {
            strokeColor: "#bdbdbd"
            strokeWidth: 1.6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M12 8C9 5 4 7 4 12.5C4 17 7.2 21 12 21S20 17 20 12.5C20 7 15 5 12 8Z M8 5L12 8L16 5L15 9L18 10L13 11L12 8L11 11L6 10L9 9Z M12 8V5C12 3.5 13 2.5 14 2" }
        }
    }
}
