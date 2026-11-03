import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Dialog {
    id: dialog
    property var courses: []
    property var checked: ({})
    title: "选择要学习的课程"
    modal: true
    closePolicy: Popup.NoAutoClose
    anchors.centerIn: Overlay.overlay
    width: Math.min(620, parent ? parent.width - 80 : 620)
    height: Math.min(560, parent ? parent.height - 80 : 560)
    standardButtons: Dialog.NoButton

    function openWith(list) {
        courses = list
        checked = ({})
        open()
    }

    function selectedIds() {
        const ids = []
        for (const c of courses) {
            if (checked[c.courseId + "/" + c.clazzId] && ids.indexOf(c.courseId) < 0)
                ids.push(c.courseId)
        }
        return ids
    }

    contentItem: ColumnLayout {
        spacing: 10
        Text {
            Layout.fillWidth: true
            text: "未填写课程 ID，任务进程正在等待选择。不勾选任何课程将学习全部课程；同一课程的多个班级会分别完成。"
            color: Theme.muted
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: dialog.courses
            ScrollBar.vertical: ScrollBar {}
            delegate: CheckDelegate {
                required property var modelData
                width: ListView.view.width
                text: modelData.title
                checked: !!dialog.checked[modelData.courseId + "/" + modelData.clazzId]
                onToggled: {
                    const next = Object.assign({}, dialog.checked)
                    next[modelData.courseId + "/" + modelData.clazzId] = checked
                    dialog.checked = next
                }
                contentItem: ColumnLayout {
                    spacing: 1
                    Text { text: modelData.title; color: Theme.text; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true; Layout.rightMargin: 40 }
                    Text { text: "课程 " + modelData.courseId + " · 班级 " + modelData.clazzId; color: Theme.muted; font.pixelSize: 11 }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "没有读取到课程列表"
                color: Theme.faint
            }
        }
    }

    footer: DialogButtonBox {
        Button {
            text: "停止任务"
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
        Button {
            text: dialog.selectedIds().length > 0 ? "学习所选 " + dialog.selectedIds().length + " 门" : "学习全部课程"
            highlighted: true
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
        }
    }

    onAccepted: controller.submitCourses(selectedIds())
    onRejected: controller.stopRun()
}
