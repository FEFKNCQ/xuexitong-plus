import QtQuick
import QtQuick.Controls
import "."

// Self-drawn combo box: field like AppTextField, popup as a rounded card with a soft
// shadow, highlighted current item, animated open/close. Looks the same under any style.
ComboBox {
    id: control
    implicitHeight: 36
    font.family: Theme.uiFont
    font.pixelSize: 13
    hoverEnabled: true
    leftPadding: 12
    rightPadding: 34
    readonly property int rowHeight: 34

    background: Rectangle {
        radius: Theme.radius
        color: !control.enabled ? Theme.sunken
            : control.pressed || control.popup.visible ? Theme.surfaceAlt
            : control.hovered ? Theme.surfaceAlt : Theme.surface
        border.width: 1
        border.color: control.popup.visible || control.visualFocus ? Theme.accent
            : control.hovered ? Theme.borderStrong : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
    }

    contentItem: Text {
        text: control.displayText
        font: control.font
        color: control.enabled ? Theme.text : Theme.faint
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.width - width - 12
        y: (control.height - height) / 2
        text: ""                       // chevron down
        font.family: Theme.iconFont
        font.pixelSize: 12
        color: control.enabled ? Theme.muted : Theme.faint
        rotation: control.popup.visible ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    }

    delegate: ItemDelegate {
        id: item
        required property int index
        required property var modelData
        readonly property bool current: control.currentIndex === index
        width: ListView.view ? ListView.view.width : control.width
        height: control.rowHeight
        padding: 0
        hoverEnabled: true
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            leftPadding: 14
            rightPadding: 30
            text: control.textRole ? (Array.isArray(control.model) ? item.modelData[control.textRole] : item.model[control.textRole])
                                   : item.modelData
            font.family: Theme.uiFont
            font.pixelSize: 13
            font.weight: item.current ? Font.DemiBold : Font.Normal
            color: item.current ? Theme.accent : Theme.text
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            radius: Theme.radius - 2
            color: item.current ? Theme.accentSoft : (item.highlighted || item.hovered ? Theme.surfaceAlt : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            // Accent bar on the selected entry (Fluent style).
            Rectangle {
                visible: item.current
                width: 3
                height: 14
                radius: 2
                color: Theme.accent
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: item.current
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.family: Theme.iconFont
                font.pixelSize: 11
                color: Theme.accent
            }
        }
    }

    popup: Popup {
        y: control.height + 4
        width: control.width
        // Height from the entry count: the list's contentHeight is not known yet when the
        // popup is sized (its delegates are created on open), which cut off the last entry.
        implicitHeight: Math.min(control.count * (control.rowHeight + 2) - 2 + topPadding + bottomPadding, 320)
        padding: 4
        transformOrigin: Item.Top

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fast }
                NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.fast }
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            spacing: 2
            ScrollIndicator.vertical: ScrollIndicator {}
        }

        background: Rectangle {
            radius: Theme.radiusLarge
            color: Theme.surface
            border.color: Theme.border
            // Soft shadow layers.
            Rectangle { z: -1; anchors.fill: parent; anchors.margins: -1; radius: Theme.radiusLarge + 1; color: "transparent"; border.color: Qt.rgba(0, 0, 0, Theme.dark ? 0.35 : 0.05) }
            Rectangle { z: -2; anchors.fill: parent; anchors.margins: -3; anchors.topMargin: 0; anchors.bottomMargin: -6; radius: Theme.radiusLarge + 3; color: Qt.rgba(0, 0, 0, Theme.dark ? 0.3 : 0.06) }
        }
    }
}
