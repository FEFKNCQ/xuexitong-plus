import QtQuick
import QtWebView
import "."

// Muted, control-less video surface. The page itself ignores pointer and keyboard input.
Rectangle {
    id: root
    property bool suspended: false
    color: "#05080f"
    radius: Theme.radius
    clip: true

    function reload() {
        if (webView.visible)
            webView.loadHtml(controller.videoHtml, controller.videoBaseUrl)
    }

    WebView {
        id: webView
        anchors.fill: parent
        anchors.margins: 1
        visible: root.visible && !root.suspended
        settings.javaScriptEnabled: true
        settings.localStorageEnabled: false
        settings.allowFileAccess: false
        settings.localContentCanAccessFileUrls: false
        onVisibleChanged: root.reload()
        Component.onCompleted: root.reload()
    }

    Connections {
        target: controller
        function onVideoChanged() { root.reload() }
    }

    // Shown while dialogs are open: the native web view would otherwise draw above them.
    Text {
        anchors.centerIn: parent
        visible: root.suspended
        text: "预览已暂停显示"
        color: "#8e9bb3"
        font.pixelSize: 13
    }
}
