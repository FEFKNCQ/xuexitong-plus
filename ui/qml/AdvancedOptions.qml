import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// 高级选项: the rest of config.ini (题库 / 答题 / 通知推送) as real controls instead of a
// text file. Fields come from controller.advancedGroups (ui/advanced.py); values are the
// strings config.ini stores and are written back on 保存 like every other setting.
Card {
    id: adv
    title: "高级选项"
    subtitle: "题库、答题和通知推送，对应配置文件 config.ini"
    icon: ""

    property int tab: 0
    readonly property var groups: controller.advancedGroups
    readonly property var values: controller.advancedValues

    function value(id) { return values[id] !== undefined ? values[id] : "" }
    function isOn(id) { return ["true", "1", "yes", "on"].indexOf(String(value(id)).toLowerCase()) >= 0 }
    function listOf(id) { return String(value(id)).split(",").map(s => s.trim()).filter(s => s !== "") }
    function shown(f) {
        const c = f.show
        if (!c) return true
        if (c.has !== undefined) { const l = listOf(c.key); return c.has.some(v => l.indexOf(v) >= 0) }
        if (c.eq !== undefined) return value(c.key) === c.eq
        if (c.ne !== undefined) return value(c.key) !== c.ne
        if (c.on !== undefined) return isOn(c.key) === c.on
        return true
    }

    actions: [
        IconButton {
            glyph: ""
            tip: "用编辑器打开 config.ini"
            onClicked: controller.openConfigFile()
        }
    ]

    Segmented {
        Layout.fillWidth: false
        model: adv.groups.map((g, i) => ({ value: String(i), label: g.title }))
        current: String(adv.tab)
        onPicked: value => adv.tab = parseInt(value)
    }
    Text {
        Layout.fillWidth: true
        text: adv.groups.length ? adv.groups[adv.tab].subtitle : ""
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }

    // One page per group; the active one slides in like the app's pages.
    Item {
        id: pages
        Layout.fillWidth: true
        implicitHeight: adv.groups.length ? stack.children[adv.tab].implicitHeight : 0
        Behavior on implicitHeight { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        clip: true
        enabled: !controller.running

        Item {
            id: stack
            anchors.fill: parent
            Repeater {
                model: adv.groups
                ColumnLayout {
                    id: groupPage
                    required property var modelData
                    required property int index
                    readonly property bool current: adv.tab === index
                    width: pages.width
                    spacing: 10
                    opacity: current ? 1 : 0
                    visible: opacity > 0.01
                    x: current ? 0 : (index < adv.tab ? -30 : 30)
                    Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }

                    Repeater {
                        model: groupPage.modelData.fields
                        Loader {
                            required property var modelData
                            Layout.fillWidth: true
                            active: adv.shown(modelData)
                            visible: active
                            property var field: modelData
                            sourceComponent: ({
                                heading: headingField, switch: switchField, number: numberField,
                                percent: percentField, choice: choiceField, providers: providersField,
                                text: textField, secret: textField
                            })[modelData.type]
                        }
                    }
                }
            }
        }
    }

    // ---------- field components (each reads `field` from its Loader) ----------

    // Label + hint on the left, control on the right.
    component FieldRow: RowLayout {
        id: row
        property var f
        default property alias control: holder.data
        spacing: 16
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { Layout.fillWidth: true; text: row.f.label; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 13 }
            Text {
                visible: row.f.hint !== ""
                Layout.fillWidth: true
                text: row.f.hint
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
        }
        Item {
            id: holder
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }

    Component {
        id: headingField
        ColumnLayout {
            readonly property var field: parent ? parent.field : ({})
            spacing: 8
            Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; height: 1; color: Theme.border }
            Text {
                text: field.label
                color: Theme.accent
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
    }

    Component {
        id: switchField
        FieldRow {
            readonly property var field: parent ? parent.field : ({})
            f: field
            AppSwitch {
                checked: adv.isOn(field.id)
                onToggled: controller.setAdvanced(field.id, checked)
            }
        }
    }

    Component {
        id: numberField
        FieldRow {
            readonly property var field: parent ? parent.field : ({})
            f: field
            AppSpinBox {
                readonly property real scale: Math.pow(10, field.decimals || 0)
                from: Math.round(field.min * scale)
                to: Math.round(field.max * scale)
                stepSize: Math.max(1, Math.round(field.step * scale))
                value: Math.round((parseFloat(adv.value(field.id)) || 0) * scale)
                textFromValue: (v, locale) => (v / scale).toFixed(field.decimals || 0) + (field.suffix ? " " + field.suffix : "")
                valueFromText: (t, locale) => Math.round((parseFloat(t) || 0) * scale)
                onValueModified: controller.setAdvanced(field.id, String(value / scale))
            }
        }
    }

    Component {
        id: percentField
        FieldRow {
            readonly property var field: parent ? parent.field : ({})
            f: field
            AppSpinBox {
                from: 0
                to: 100
                stepSize: 5
                value: Math.round((parseFloat(adv.value(field.id)) || 0) * 100)
                textFromValue: (v, locale) => v + " %"
                valueFromText: (t, locale) => Math.round(parseFloat(t) || 0)
                onValueModified: controller.setAdvanced(field.id, String(value / 100))
            }
        }
    }

    Component {
        id: choiceField
        FieldRow {
            readonly property var field: parent ? parent.field : ({})
            f: field
            Segmented {
                model: field.options
                current: adv.value(field.id)
                onPicked: value => controller.setAdvanced(field.id, value)
            }
        }
    }

    Component {
        id: textField
        ColumnLayout {
            readonly property var field: parent ? parent.field : ({})
            spacing: 6
            Text { text: field.label; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 13 }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                AppTextField {
                    Layout.fillWidth: true
                    placeholderText: field.default !== "" ? field.default : (field.type === "secret" ? "未填写" : "")
                    echoMode: field.type === "secret" && !reveal.checked ? TextInput.Password : TextInput.Normal
                    text: adv.value(field.id)
                    onTextEdited: controller.setAdvanced(field.id, text)
                }
                IconButton {
                    id: reveal
                    visible: field.type === "secret"
                    checkable: true
                    glyph: checked ? "" : ""
                    tip: checked ? "隐藏" : "显示"
                }
            }
            Text {
                visible: field.hint !== ""
                Layout.fillWidth: true
                text: field.hint
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
        }
    }

    // Ordered multi-select: the badge shows the query order.
    Component {
        id: providersField
        ColumnLayout {
            readonly property var field: parent ? parent.field : ({})
            spacing: 8
            Text { text: field.label; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 13 }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: field.options
                    Rectangle {
                        id: chip
                        required property var modelData
                        readonly property var picked: adv.listOf(field.id)
                        readonly property int order: picked.indexOf(modelData.value)
                        readonly property bool on: order >= 0
                        width: chipRow.implicitWidth + 24
                        height: 34
                        radius: 17
                        color: on ? Theme.accentSoft : (chipHover.hovered ? Theme.surfaceAlt : Theme.surface)
                        border.color: on ? Theme.accent : (chipHover.hovered ? Theme.borderStrong : Theme.border)
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
                        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                        ToolTip.visible: chipHover.hovered
                        ToolTip.delay: 500
                        ToolTip.text: modelData.hint
                        TapHandler {
                            onTapped: {
                                const l = chip.picked.slice()
                                if (chip.on) l.splice(chip.order, 1)
                                else l.push(chip.modelData.value)
                                controller.setAdvanced(field.id, l)
                            }
                        }
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                color: chip.on ? Theme.accent : "transparent"
                                border.color: chip.on ? Theme.accent : Theme.borderStrong
                                scale: chip.on ? 1 : 0.85
                                Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutBack } }
                                Text {
                                    anchors.centerIn: parent
                                    text: chip.on ? String(chip.order + 1) : ""
                                    color: Theme.accentText
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.label
                                color: chip.on ? Theme.accent : Theme.text
                                font.family: Theme.uiFont
                                font.pixelSize: 13
                                font.weight: chip.on ? Font.DemiBold : Font.Normal
                            }
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: field.hint
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
        }
    }
}
