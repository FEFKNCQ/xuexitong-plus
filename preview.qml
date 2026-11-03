import QtQuick
import QtWebView

Rectangle {
    id: root
    width: 960
    height: 540
    color: "#080d16"

    WebView {
        id: webView
        anchors.fill: parent
        settings.javaScriptEnabled: true
        settings.localStorageEnabled: false
        settings.allowFileAccess: false
        settings.localContentCanAccessFileUrls: false
    }

    Connections {
        target: previewBridge

        function onHtmlRequested(markup, baseUrl) {
            webView.stop()
            webView.loadHtml(markup, baseUrl)
        }
    }
}
