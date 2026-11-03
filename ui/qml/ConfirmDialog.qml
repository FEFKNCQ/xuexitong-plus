import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Dialog {
    id: dialog
    property string message: ""
    property string acceptText: "确定"
    property string rejectText: "取消"
    property bool destructive: false
    modal: true
    anchors.centerIn: Overlay.overlay
    width: 420
    standardButtons: Dialog.NoButton

    contentItem: Text {
        text: dialog.message
        color: Theme.text
        font.pixelSize: 13
        wrapMode: Text.Wrap
    }

    footer: DialogButtonBox {
        Button {
            text: dialog.rejectText
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
        Button {
            text: dialog.acceptText
            highlighted: true
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
        }
    }
}
