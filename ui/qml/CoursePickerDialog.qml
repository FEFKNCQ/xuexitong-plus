import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

BaseDialog {
    id: dialog
    property var courses: []
    property var checked: ({})
    readonly property var selected: selectedIds()
    title: "选择要学习的课程"
    closePolicy: Popup.NoAutoClose
    width: Math.min(620, parent ? parent.width - 80 : 620)
    height: Math.min(560, parent ? parent.height - 80 : 560)

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

    function toggle(key) {
        const next = Object.assign({}, checked)
        next[key] = !next[key]
        checked = next
    }

    contentItem: ColumnLayout {
        spacing: 12
        Text {
            Layout.fillWidth: true
            text: "未填写课程 ID，任务进程正在等待选择。不勾选任何课程将学习全部课程；同一课程的多个班级会分别完成。"
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: dialog.courses
            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property string key: modelData.courseId + "/" + modelData.clazzId
                readonly property bool on: !!dialog.checked[key]
                width: ListView.view.width - 8
                height: 56
                radius: Theme.radius
                color: on ? Theme.accentSoft : (rowHover.hovered ? Theme.surfaceAlt : Theme.surface)
                border.color: on ? Theme.accent : Theme.border
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                Behavior on border.color { ColorAnimation { duration: Theme.fast } }

                // Staggered entrance.
                opacity: 0
                transform: Translate { id: slide; y: 10 }
                Component.onCompleted: appear.start()
                SequentialAnimation {
                    id: appear
                    PauseAnimation { duration: Math.min(row.index, 10) * 40 }
                    ParallelAnimation {
                        NumberAnimation { target: row; property: "opacity"; to: 1; duration: Theme.normal }
                        NumberAnimation { target: slide; property: "y"; to: 0; duration: Theme.normal; easing.type: Easing.OutCubic }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12
                    AppCheckBox {
                        checked: row.on
                        onClicked: dialog.toggle(row.key)
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: modelData.title; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: "课程 " + modelData.courseId + " · 班级 " + modelData.clazzId; color: Theme.muted; font.pixelSize: 11 }
                    }
                }
                HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: dialog.toggle(row.key) }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "没有读取到课程列表"
                color: Theme.faint
            }
        }
    }

    buttons: [
        AppButton { text: "停止任务"; kind: "danger"; onClicked: dialog.reject() },
        AppButton {
            text: dialog.selected.length > 0 ? "学习所选 " + dialog.selected.length + " 门" : "学习全部课程"
            kind: "primary"
            onClicked: dialog.accept()
        }
    ]

    onAccepted: controller.submitCourses(selectedIds())
    onRejected: controller.stopRun()
}
