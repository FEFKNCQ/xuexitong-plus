import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// "AI 讲解": a local GGUF model (llama.cpp) explains questions for the user to read.
// Results are never filled in or submitted anywhere; each one waits for human review.
Item {
    id: page
    property string source: "work"           // work | text | image
    property string imagePath: ""
    property string selectedId: ""           // history item shown in the result card
    property bool detectedOnce: false

    readonly property var work: controller.work
    readonly property var questions: (work && work.questions) ? work.questions : []
    readonly property bool running: ai.serverState === "running"
    readonly property var shown: {
        const id = page.selectedId !== "" ? page.selectedId : ai.currentId
        for (const h of ai.history) if (h.id === id) return h
        return null
    }
    // While generating, show the live stream; otherwise the selected / latest history item.
    readonly property bool live: ai.busy || (page.shown === null && ai.output !== "")
    readonly property string showAnalysis: live ? ai.analysis : (shown ? shown.analysis : "")
    readonly property string showAnswer: live ? ai.answer : (shown ? shown.answer : "")
    readonly property string showStatus: live ? "generating" : (shown ? shown.status : "")

    onVisibleChanged: if (visible && !detectedOnce) { detectedOnce = true; ai.detect() }

    Connections {
        target: ai
        function onHistoryChanged() { page.selectedId = "" }   // jump to the newest result
    }

    function statusText(s) {
        return s === "approved" ? "已采纳" : s === "rejected" ? "有误" : s === "pending" ? "待审核" : s === "generating" ? "生成中" : ""
    }
    function statusKind(s) {
        return s === "approved" ? "done" : s === "rejected" ? "error" : s === "generating" ? "running" : "idle"
    }
    function serverText() {
        return {
            stopped: "未启动", starting: "启动中", running: "运行中", error: "出错"
        }[ai.serverState] || ai.serverState
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.gap

        // ================= left: model, settings, log =================
        ColumnLayout {
            Layout.preferredWidth: Math.max(430, page.width * 0.40)
            Layout.maximumWidth: 560
            Layout.fillHeight: true
            spacing: Theme.gap

            ColumnLayout {
                spacing: 2
                Text { text: "AI 讲解"; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 22; font.weight: Font.DemiBold }
                Text {
                    text: "本地模型讲解题目，仅供学习参考；不会自动填写或提交，结果需要你自己审核"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }
            }

            // ---------- model status ----------
            Card {
                Layout.fillWidth: true
                title: "本地模型"
                subtitle: ai.modelName !== "" ? ai.modelName : (ai.managed ? "llama.cpp · GGUF" : "外部服务 · " + ai.baseUrl)
                icon: ""
                appearDelay: 40
                actions: [ StatusPill { text: page.serverText(); kind: ai.serverState === "running" ? "done" : ai.serverState === "error" ? "error" : ai.serverState === "starting" ? "running" : "idle" } ]

                Text {
                    Layout.fillWidth: true
                    visible: ai.managed
                    text: ai.detectState === "detecting" ? "正在检测 llama-server…"
                        : ai.detectState === "found" ? "llama-server " + ai.serverVersion + " · 已找到"
                        : ai.detectState === "missing" ? "没有找到 llama-server，请在下方“模型设置”里选择 llama-server.exe"
                        : "llama-server 尚未检测"
                    color: ai.detectState === "missing" ? Theme.warning : Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    visible: ai.serverMessage !== ""
                    text: ai.serverMessage
                    color: ai.serverState === "error" ? Theme.danger : Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    AppButton {
                        visible: ai.serverState !== "running" && ai.serverState !== "starting"
                        text: ai.managed ? "启动模型" : "连接服务"
                        glyph: ""
                        kind: "primary"
                        onClicked: ai.startServer()
                    }
                    AppButton {
                        visible: ai.serverState === "running" || ai.serverState === "starting"
                        text: ai.managed ? "停止模型" : "断开"
                        glyph: ""
                        kind: "danger"
                        onClicked: ai.stopServer()
                    }
                    IconButton { glyph: ""; text: "连接测试"; flat: false; enabled: page.running; onClicked: ai.testConnection() }
                    IconButton { visible: ai.managed; glyph: ""; text: "检测 llama-server"; flat: false; enabled: ai.detectState !== "detecting"; onClicked: ai.detect() }
                }
            }

            // ---------- settings ----------
            Card {
                id: settingsCard
                property bool expanded: ai.settings.model_path === "" && ai.settings.external_url === ""
                Layout.fillWidth: true
                title: "模型设置"
                subtitle: "设置保存在本机，与刷课任务的配置分开"
                icon: ""
                appearDelay: 80
                actions: [ IconButton { glyph: settingsCard.expanded ? "" : ""; tip: settingsCard.expanded ? "收起" : "展开"; onClicked: settingsCard.expanded = !settingsCard.expanded } ]

                // Collapsed by animating an explicit height (toggling `visible` alone leaves the
                // card at its expanded height).
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: settingsCard.expanded ? settingsBody.implicitHeight : 0
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                    clip: true
                    visible: Layout.preferredHeight > 0.5
                ColumnLayout {
                    id: settingsBody
                    width: parent.width
                    spacing: 8
                    enabled: ai.serverState !== "running" && ai.serverState !== "starting"
                    opacity: enabled ? 1 : 0.6

                    Segmented {
                        model: [{ value: "managed", label: "本机启动 llama-server" }, { value: "external", label: "连接已运行的服务" }]
                        current: ai.managed ? "managed" : "external"
                        onPicked: value => {
                            if (value === "managed") ai.setSetting("external_url", "")
                            else if (ai.managed) ai.setSetting("external_url", "http://127.0.0.1:8080")
                        }
                    }

                    component PathRow: RowLayout {
                        id: pathRow
                        property string label: ""
                        property string key: ""
                        property string kind: ""
                        property string placeholder: ""
                        property bool clearable: false
                        Layout.fillWidth: true
                        spacing: 6
                        Label { text: pathRow.label; color: Theme.muted; font.family: Theme.uiFont; Layout.preferredWidth: 78 }
                        AppTextField {
                            Layout.fillWidth: true
                            placeholderText: pathRow.placeholder
                            text: ai.settings[pathRow.key] || ""
                            onEditingFinished: ai.setSetting(pathRow.key, text)
                        }
                        IconButton { glyph: ""; tip: "浏览"; flat: false; onClicked: ai.browse(pathRow.kind) }
                        IconButton { visible: pathRow.clearable && (ai.settings[pathRow.key] || "") !== ""; glyph: ""; tip: "清除"; onClicked: ai.clearSetting(pathRow.key) }
                    }

                    PathRow { visible: ai.managed; label: "llama-server"; key: "server_path"; kind: "server"; placeholder: "留空则自动检测"; clearable: true }
                    PathRow { visible: ai.managed; label: "GGUF 模型"; key: "model_path"; kind: "model"; placeholder: "选择本地 .gguf 模型文件" }
                    PathRow { visible: ai.managed; label: "mmproj"; key: "mmproj_path"; kind: "mmproj"; placeholder: "可选：图片题需要多模态投影文件"; clearable: true }
                    RowLayout {
                        visible: !ai.managed
                        Layout.fillWidth: true
                        spacing: 6
                        Label { text: "服务地址"; color: Theme.muted; font.family: Theme.uiFont; Layout.preferredWidth: 78 }
                        AppTextField {
                            Layout.fillWidth: true
                            placeholderText: "http://127.0.0.1:8080"
                            text: ai.settings.external_url || ""
                            onEditingFinished: ai.setSetting("external_url", text)
                        }
                    }

                    component NumberField: ColumnLayout {
                        id: nf
                        property string label: ""
                        property string key: ""
                        property int from: 0
                        property int to: 100
                        property int scale: 1          // temperature is stored as a float, edited x10
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: nf.label; color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 11 }
                        AppSpinBox {
                            Layout.fillWidth: true
                            from: nf.from
                            to: nf.to
                            editable: true
                            value: Math.round((ai.settings[nf.key] || 0) * nf.scale)
                            textFromValue: (v, locale) => nf.scale === 1 ? String(v) : (v / nf.scale).toFixed(1)
                            valueFromText: (t, locale) => Math.round(parseFloat(t) * nf.scale)
                            onValueModified: ai.setSetting(nf.key, nf.scale === 1 ? value : value / nf.scale)
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 8
                        rowSpacing: 6
                        NumberField { visible: ai.managed; label: "端口"; key: "port"; from: 1; to: 65535 }
                        NumberField { visible: ai.managed; label: "上下文长度"; key: "ctx_size"; from: 256; to: 131072 }
                        NumberField { visible: ai.managed; label: "GPU 层数"; key: "gpu_layers"; from: 0; to: 999 }
                        NumberField { visible: ai.managed; label: "线程（0=自动）"; key: "threads"; from: 0; to: 256 }
                        NumberField { label: "温度"; key: "temperature"; from: 0; to: 20; scale: 10 }
                        NumberField { label: "最大输出 token"; key: "max_tokens"; from: 64; to: 32768 }
                    }
                    RowLayout {
                        visible: ai.managed
                        Layout.fillWidth: true
                        spacing: 6
                        Label { text: "额外参数"; color: Theme.muted; font.family: Theme.uiFont; Layout.preferredWidth: 78 }
                        AppTextField {
                            Layout.fillWidth: true
                            placeholderText: "可选，例如 --flash-attn on"
                            text: ai.settings.extra_args || ""
                            onEditingFinished: ai.setSetting("extra_args", text)
                        }
                    }
                    Text {
                        readonly property var problems: (ai.settings, ai.validationProblems())
                        visible: problems.length > 0
                        Layout.fillWidth: true
                        text: "⚠ " + problems.join("；")
                        color: Theme.warning
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }
                }
            }

            // ---------- inference log ----------
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "推理日志"
                icon: ""
                appearDelay: 120
                actions: [ IconButton { glyph: ""; tip: "清空日志"; onClicked: ai.logModel.clear() } ]
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 80
                    radius: Theme.radius
                    color: Theme.sunken
                    ListView {
                        id: aiLog
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        model: ai.logModel
                        onCountChanged: Qt.callLater(positionViewAtEnd)
                        ScrollBar.vertical: ScrollBar {}
                        delegate: RowLayout {
                            required property string level
                            required property string message
                            required property string time
                            width: ListView.view.width - 10
                            spacing: 8
                            Text { text: time; color: Theme.faint; font.family: Theme.monoFont; font.pixelSize: 11; Layout.alignment: Qt.AlignTop }
                            Text {
                                Layout.fillWidth: true
                                text: message
                                color: level === "ERROR" ? Theme.danger : level === "WARNING" ? Theme.warning : level === "SUCCESS" ? Theme.success : Theme.text
                                font.family: Theme.monoFont
                                font.pixelSize: 11
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                        Text { anchors.centerIn: parent; visible: aiLog.count === 0; text: "暂无日志"; color: Theme.faint; font.pixelSize: 12 }
                    }
                }
            }
        }

        // ================= right: question, result, history =================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.gap

            // ---------- question ----------
            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(330, page.height * 0.40)
                title: "题目"
                subtitle: ai.courseName !== "" ? "当前课程：" + ai.courseName + (ai.chapterName !== "" ? " · " + ai.chapterName : "")
                                               : "运行任务后会自动识别当前课程和章节，讲解时一并提供给模型"
                icon: ""
                appearDelay: 60
                actions: [ Segmented {
                    model: [{ value: "work", label: "章节检测" }, { value: "text", label: "手动输入" }, { value: "image", label: "图片" }]
                    current: page.source
                    onPicked: value => page.source = value
                } ]

                // From the current chapter quiz (read from the run dashboard).
                ListView {
                    visible: page.source === "work"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: page.questions
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: ListView.view.width - 8
                        height: 44
                        radius: Theme.radius
                        color: rowHover.hovered ? Theme.surfaceAlt : Theme.sunken
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        HoverHandler { id: rowHover }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 6
                            spacing: 8
                            Text { text: (index + 1) + "."; color: Theme.text; font.family: Theme.uiFont; font.weight: Font.DemiBold; font.pixelSize: 12 }
                            Text { text: modelData.typeLabel || ""; color: Theme.accent; font.family: Theme.uiFont; font.pixelSize: 11 }
                            Text { Layout.fillWidth: true; text: modelData.title || ""; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 12; elide: Text.ElideRight }
                            AppButton { text: "讲解"; implicitHeight: 30; enabled: page.running && !ai.busy; onClicked: ai.explainWork(index) }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: page.questions.length === 0
                        width: parent.width - 40
                        horizontalAlignment: Text.AlignHCenter
                        text: "运行面板里出现章节检测后，题目会自动列在这里；也可以切换到“手动输入”或“图片”"
                        color: Theme.faint
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }

                // Manual input / image.
                ColumnLayout {
                    visible: page.source !== "work"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    RowLayout {
                        visible: page.source === "image"
                        Layout.fillWidth: true
                        spacing: 8
                        IconButton {
                            glyph: ""
                            text: page.imagePath === "" ? "选择题目图片" : "更换图片"
                            flat: false
                            onClicked: { const p = ai.browseImage(); if (p !== "") page.imagePath = p }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: page.imagePath === "" ? (ai.settings.mmproj_path === "" && ai.managed ? "图片题需要先在模型设置里配置 mmproj" : "支持 png / jpg / bmp / webp")
                                                        : page.imagePath.split(/[\\/]/).pop()
                            color: page.imagePath === "" ? Theme.faint : Theme.text
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            elide: Text.ElideMiddle
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radius
                        color: Theme.surface
                        border.color: questionInput.activeFocus ? Theme.accent : Theme.border
                        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
                        ScrollView {
                            id: qScroll
                            anchors.fill: parent
                            anchors.margins: 2
                            clip: true
                            TextArea {
                                id: questionInput
                                objectName: "aiQuestionInput"
                                width: qScroll.availableWidth
                                wrapMode: TextEdit.Wrap
                                selectByMouse: true
                                color: Theme.text
                                placeholderText: page.source === "image" ? "可选：补充题目文字或说明" : "粘贴或输入题目，选项每行一个，例如：\nA. 速度\nB. 加速度"
                                placeholderTextColor: Theme.faint
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                                background: null
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        AppButton { text: "清空"; onClicked: { questionInput.text = ""; page.imagePath = "" } }
                        AppButton {
                            text: "讲解"
                            glyph: ""
                            kind: "primary"
                            enabled: page.running && !ai.busy && (questionInput.text.trim() !== "" || (page.source === "image" && page.imagePath !== ""))
                            onClicked: ai.explainText(questionInput.text, page.source === "image" ? page.imagePath : "")
                        }
                    }
                }
            }

            // ---------- result + review ----------
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "讲解结果"
                subtitle: "仅供学习参考 · 不会自动填写或提交 · 请自行核对后再采纳"
                icon: ""
                appearDelay: 120
                actions: [
                    StatusPill { visible: page.showStatus !== ""; text: page.statusText(page.showStatus); kind: page.statusKind(page.showStatus) },
                    AppButton { visible: ai.busy; text: "停止生成"; kind: "danger"; implicitHeight: 30; onClicked: ai.cancel() }
                ]

                ScrollView {
                    id: resultScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: resultScroll.availableWidth
                        spacing: 10
                        Text {
                            visible: ai.errorText !== "" && !ai.busy && page.selectedId === ""
                            Layout.fillWidth: true
                            text: "⚠ " + ai.errorText
                            color: Theme.danger
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                        Text {
                            visible: page.showAnalysis === "" && page.showAnswer === "" && !ai.busy && ai.errorText === ""
                            Layout.fillWidth: true
                            text: page.running ? "选择一道题点“讲解”，模型的解析和参考答案会显示在这里" : "先在左侧启动本地模型（或连接已运行的服务）"
                            color: Theme.faint
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                        Text { visible: page.showAnalysis !== ""; text: "解析"; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Text {
                            visible: page.showAnalysis !== ""
                            Layout.fillWidth: true
                            text: page.showAnalysis + (ai.busy && page.showAnswer === "" ? " ▍" : "")
                            textFormat: Text.MarkdownText
                            color: Theme.text
                            font.family: Theme.uiFont
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                        }
                        Rectangle {
                            visible: page.showAnswer !== ""
                            Layout.fillWidth: true
                            implicitHeight: answerCol.implicitHeight + 20
                            radius: Theme.radius
                            color: Theme.accentSoft
                            border.color: Theme.accent
                            ColumnLayout {
                                id: answerCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4
                                Text { text: "参考答案"; color: Theme.accent; font.family: Theme.uiFont; font.pixelSize: 12; font.weight: Font.DemiBold }
                                Text {
                                    Layout.fillWidth: true
                                    text: page.showAnswer + (ai.busy ? " ▍" : "")
                                    textFormat: Text.MarkdownText
                                    color: Theme.text
                                    font.family: Theme.uiFont
                                    font.pixelSize: 13
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }

                // Human review: required before an answer can be copied.
                RowLayout {
                    visible: page.shown !== null && !ai.busy
                    Layout.fillWidth: true
                    spacing: 8
                    AppTextField {
                        id: reviewNote
                        Layout.fillWidth: true
                        placeholderText: "审核备注（可选），例如：已对照教材第 3 章"
                        text: page.shown ? page.shown.note : ""
                    }
                    AppButton { objectName: "approveButton"; text: "采纳"; glyph: ""; kind: page.shown && page.shown.status === "approved" ? "primary" : "secondary"
                        onClicked: ai.review(page.shown.id, "approved", reviewNote.text) }
                    AppButton { text: "有误"; glyph: ""; kind: page.shown && page.shown.status === "rejected" ? "danger" : "secondary"
                        onClicked: ai.review(page.shown.id, "rejected", reviewNote.text) }
                    IconButton { glyph: ""; text: "复制"; flat: false
                        enabled: page.shown !== null && page.shown.status === "approved"
                        tip: "只有标记为“采纳”的结果可以复制"
                        onClicked: ai.copyAnswer(page.shown.id) }
                }
            }

            // ---------- history ----------
            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                title: "历史记录"
                subtitle: ai.history.length > 0 ? "共 " + ai.history.length + " 条 · 点击查看" : "讲解结果和审核状态保存在本机"
                icon: ""
                appearDelay: 160
                actions: [ IconButton { visible: ai.history.length > 0; glyph: ""; tip: "清空历史"; onClicked: ai.clearHistory() } ]
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    clip: true
                    spacing: 8
                    model: ai.history
                    ScrollBar.horizontal: ScrollBar {}
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool current: page.shown !== null && page.shown.id === modelData.id
                        width: 200
                        height: ListView.view.height - 10
                        radius: Theme.radius
                        color: current ? Theme.accentSoft : (hHover.hovered ? Theme.surfaceAlt : Theme.sunken)
                        border.color: current ? Theme.accent : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        HoverHandler { id: hHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: page.selectedId = modelData.id }
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2
                            RowLayout {
                                Text { text: modelData.created; color: Theme.faint; font.family: Theme.uiFont; font.pixelSize: 10; Layout.fillWidth: true }
                                Text {
                                    text: page.statusText(modelData.status)
                                    color: modelData.status === "approved" ? Theme.success : modelData.status === "rejected" ? Theme.danger : Theme.warning
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: modelData.question.replace(/^(课程|章节|题型)：.*\n/gm, "").replace(/^题目：/, "")
                                color: Theme.text
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                                maximumLineCount: 3
                            }
                        }
                    }
                }
            }
        }
    }
}
