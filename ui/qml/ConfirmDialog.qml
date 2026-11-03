import QtQuick
import "."

BaseDialog {
    id: dialog
    property string message: ""
    property string acceptText: "确定"
    property string rejectText: "取消"
    property bool destructive: false
    width: 440

    contentItem: Text {
        text: dialog.message
        color: Theme.text
        font.family: Theme.uiFont
        font.pixelSize: 13
        lineHeight: 1.3
        wrapMode: Text.Wrap
    }

    buttons: [
        AppButton { text: dialog.rejectText; onClicked: dialog.reject() },
        AppButton { text: dialog.acceptText; kind: dialog.destructive ? "danger" : "primary"; onClicked: dialog.accept() }
    ]
}
