import QtQuick
import "."

// Compact icon button; flat (ghost) by default, `flat: false` gives the bordered look.
AppButton {
    property bool flat: true
    kind: flat ? "ghost" : "secondary"
    implicitHeight: text !== "" ? 34 : 30
    implicitWidth: text !== "" ? Math.max(88, contentItem.implicitWidth + 28) : 30
    font.pixelSize: 12
}
