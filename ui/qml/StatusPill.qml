import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: pill
    property string text: ""
    property string kind: "idle"   // idle | running | done | error

    readonly property color fg: kind === "running" ? Theme.warning
        : kind === "error" ? Theme.danger
        : kind === "done" ? Theme.success : Theme.muted
    readonly property color bgc: kind === "running" ? Theme.warningSoft
        : kind === "error" ? Theme.dangerSoft
        : kind === "done" ? Theme.successSoft : Theme.surfaceAlt

    color: bgc
    Behavior on color { ColorAnimation { duration: Theme.normal } }
    radius: height / 2
    implicitHeight: 28
    implicitWidth: row.implicitWidth + 24

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Rectangle {
            width: 8; height: 8; radius: 4
            color: pill.fg
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            SequentialAnimation on opacity {
                running: pill.kind === "running"
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 700 }
                NumberAnimation { to: 1; duration: 700 }
                onRunningChanged: if (!running) parent.opacity = 1
            }
        }
        Text {
            text: pill.text
            color: pill.fg
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }
}
