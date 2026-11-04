pragma Singleton
import QtQuick

QtObject {
    readonly property bool dark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark

    // Surfaces
    readonly property color bg: dark ? "#1c1c1f" : "#f3f4f8"
    readonly property color pane: dark ? "#202024" : "#eceef4"
    readonly property color surface: dark ? "#2a2a2f" : "#ffffff"
    readonly property color surfaceAlt: dark ? "#323238" : "#f6f7fa"
    readonly property color sunken: dark ? "#18181b" : "#eef0f5"
    readonly property color border: dark ? "#3a3a41" : "#e3e5ec"
    readonly property color borderStrong: dark ? "#4a4a52" : "#d0d4de"

    // Text
    readonly property color text: dark ? "#f2f3f5" : "#1b1d24"
    readonly property color muted: dark ? "#a2a6b2" : "#616778"
    readonly property color faint: dark ? "#757a87" : "#8c91a0"

    // Accent and status
    readonly property color accent: dark ? "#6aa8ff" : "#2563eb"
    readonly property color accentHover: dark ? "#82b6ff" : "#1d55d6"
    readonly property color accentPressed: dark ? "#5a96ec" : "#1847b5"
    readonly property color accentText: dark ? "#0b1530" : "#ffffff"
    readonly property color accentSoft: dark ? "#22324d" : "#e6eeff"
    readonly property color success: dark ? "#5fd39b" : "#13865a"
    readonly property color successSoft: dark ? "#1e3a2d" : "#e2f5eb"
    readonly property color warning: dark ? "#f2c45f" : "#a86200"
    readonly property color warningSoft: dark ? "#3d331b" : "#fff2db"
    readonly property color danger: dark ? "#ff8a8a" : "#c8323f"
    readonly property color dangerSoft: dark ? "#45242a" : "#fde8ea"

    readonly property int radius: 8
    readonly property int radiusLarge: 12
    readonly property int gap: 12
    readonly property int pad: 16

    // Motion. "界面动画" off in settings turns every transition into an instant change.
    // (The installer has no `controller`, so it always animates.)
    readonly property bool motion: typeof controller === "undefined" || !controller || controller.animationsEnabled
    // Set by the main window: false while it is hidden (tray) or minimized, so endless
    // animations and the video preview stop instead of running where nobody sees them.
    property bool onScreen: true
    readonly property bool loopMotion: motion && onScreen
    readonly property int fast: motion ? 140 : 0
    readonly property int normal: motion ? 240 : 0
    readonly property int slow: motion ? 380 : 0

    readonly property string uiFont: "Microsoft YaHei UI"

    readonly property string iconFont: Qt.fontFamilies().indexOf("Segoe Fluent Icons") >= 0
        ? "Segoe Fluent Icons" : "Segoe MDL2 Assets"
    readonly property string monoFont: Qt.fontFamilies().indexOf("Cascadia Mono") >= 0 ? "Cascadia Mono" : "Consolas"

    function levelColor(level) {
        if (level === "ERROR" || level === "CRITICAL") return danger
        if (level === "WARNING") return warning
        if (level === "SUCCESS") return success
        return muted
    }
}
