import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Settings.js" as Settings

// Full-width black glow behind the stock Omarchy bar, with forced white
// bar content. Not a bar replacement: kind is service, not bar.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string pluginId: (manifest && manifest.id) ? String(manifest.id) : "bar-glow"
  readonly property string home: Quickshell.env("HOME")
  readonly property string toggleDir: home + "/.local/state/omarchy/toggles"
  readonly property string userConfigPath: home + "/.config/omarchy/shell.json"
  readonly property color white: Qt.rgba(1, 1, 1, 1)

  readonly property var bar: shell && shell.bar ? shell.bar : null

  readonly property var pluginEntry: Settings.findEntry(shell ? shell.shellConfig : null, pluginId)
  readonly property var liveSettings: Settings.snapshot(pluginEntry)

  function setting(name, fallback) {
    return Settings.readKey(root.pluginEntry, name, fallback)
  }

  function boolSetting(name, fallback) {
    return Settings.boolValue(setting(name, fallback), fallback)
  }

  function normalizePosition(value) {
    var edge = String(value || "top").toLowerCase()
    if (edge === "bottom" || edge === "left" || edge === "right") return edge
    return "top"
  }

  function parseColor(value, fallback) {
    var text = String(value || "").replace(/^\s+|\s+$/g, "")
    if (!text) return fallback
    if (text === "black") return Qt.rgba(0, 0, 0, 1)
    if (text === "white") return Qt.rgba(1, 1, 1, 1)

    var rgba = text.match(/^rgba?\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)(?:\s*[,\s]\s*([0-9.]+))?\s*\)$/i)
    if (rgba) {
      var r = Number(rgba[1]), g = Number(rgba[2]), b = Number(rgba[3])
      var a = rgba[4] !== undefined ? Number(rgba[4]) : 1
      if (!isFinite(r) || !isFinite(g) || !isFinite(b) || !isFinite(a)) return fallback
      if (r > 1 || g > 1 || b > 1) { r /= 255; g /= 255; b /= 255 }
      return Qt.rgba(r, g, b, a)
    }

    try {
      var parsed = Qt.color(text)
      if (parsed) return parsed
    } catch (e) {
    }
    return fallback
  }

  function colorsClose(a, b) {
    return Math.abs(a.r - b.r) < 0.01 && Math.abs(a.g - b.g) < 0.01
      && Math.abs(a.b - b.b) < 0.01 && Math.abs(a.a - b.a) < 0.01
  }

  function colorHex(value) {
    var c = value
    if (typeof c === "string") c = Qt.color(c)
    function hexChannel(channel) {
      var s = Math.round(Util.clamp(channel, 0, 1) * 255).toString(16)
      return s.length < 2 ? "0" + s : s
    }
    return "#" + hexChannel(c.r) + hexChannel(c.g) + hexChannel(c.b)
  }

  readonly property bool settingsEnabled: liveSettings.enabled
  readonly property bool forceWhite: liveSettings.forceWhite
  readonly property bool followTheme: liveSettings.followTheme
    || String(liveSettings.color) === "theme"
    || String(liveSettings.contentColor) === "theme"
  readonly property int glowSize: liveSettings.size
  readonly property color parsedGlow: parseColor(liveSettings.color, Qt.rgba(0, 0, 0, 1))
  readonly property color contentColor: followTheme
    ? Color.foreground
    : parseColor(liveSettings.contentColor, white)
  readonly property real peakOpacity: liveSettings.opacity
  readonly property color glowBase: followTheme
    ? Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 1)
    : Qt.rgba(parsedGlow.r, parsedGlow.g, parsedGlow.b, 1)

  readonly property string configPosition: {
    if (bar && bar.position) return normalizePosition(bar.position)
    var barConfig = shell && shell.barConfig
    if (barConfig && barConfig.position) return normalizePosition(barConfig.position)
    return normalizePosition(filePosition)
  }

  readonly property bool vertical: configPosition === "left" || configPosition === "right"
  readonly property int liveBarSize: {
    if (bar && bar.barSize > 0) return bar.barSize
    return vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  }

  property bool barOffFlag: false
  readonly property bool barHidden: {
    if (bar && "barHidden" in bar) return bar.barHidden === true
    return barOffFlag
  }

  property bool layersBarVisible: true

  readonly property bool glowShown: settingsEnabled && !barHidden && layersBarVisible
    && liveBarSize > 0 && peakOpacity > 0

  property string filePosition: "top"
  property bool restoringContent: false

  function applyShellFile(raw) {
    try {
      var parsed = JSON.parse(raw)
      if (parsed && parsed.bar && parsed.bar.position)
        filePosition = normalizePosition(parsed.bar.position)
    } catch (e) {
    }
  }

  function applyWhiteContent() {
    if (restoringContent) return
    if (!settingsEnabled || !forceWhite) return

    if (Color.bar && !colorsClose(Color.bar.text, contentColor))
      Color.bar.text = contentColor

    var b = root.bar
    if (!b) return
    if (!colorsClose(b.transparentForeground, contentColor)) {
      b.foregroundAnimationEnabled = false
      b.transparentForeground = contentColor
      Qt.callLater(function() {
        if (root.bar) root.bar.foregroundAnimationEnabled = true
      })
    }
  }

  function restoreContentColor() {
    restoringContent = true
    if (Color.bar && typeof Color.pick === "function")
      Color.bar.text = Color.pick("bar.text", Color.foreground)
    restoringContent = false
  }

  function screenByName(name) {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && screens[i].name === name) return screens[i]
    }
    return null
  }

  function surfaceOnOutput(surf, monitorName) {
    var x = Number(surf.x), y = Number(surf.y), w = Number(surf.w), h = Number(surf.h)
    if (!isFinite(x) || !isFinite(y) || !isFinite(w) || !isFinite(h) || w <= 0 || h <= 0)
      return false
    var screen = screenByName(monitorName)
    var sw = screen ? screen.width : 1e9
    var sh = screen ? screen.height : 1e9
    return x < sw && y < sh && (x + w) > 0 && (y + h) > 0
  }

  function applyLayers(raw) {
    var found = false
    var visible = false
    try {
      var data = JSON.parse(raw)
      for (var monitor in data) {
        var levels = data[monitor] && data[monitor].levels
        if (!levels) continue
        for (var level in levels) {
          var list = levels[level]
          if (!Array.isArray(list)) continue
          for (var i = 0; i < list.length; i++) {
            var surf = list[i]
            if (!surf || String(surf.namespace) !== "omarchy-bar") continue
            found = true
            if (surfaceOnOutput(surf, monitor)) visible = true
          }
        }
      }
    } catch (e) {
      layersBarVisible = true
      return
    }
    layersBarVisible = found && visible
  }

  onBarChanged: {
    if (root.bar) root.layersBarVisible = true
    Qt.callLater(root.applyWhiteContent)
  }
  onForceWhiteChanged: forceWhite ? applyWhiteContent() : restoreContentColor()
  onFollowThemeChanged: applyWhiteContent()
  onSettingsEnabledChanged: settingsEnabled && forceWhite ? applyWhiteContent() : restoreContentColor()
  onContentColorChanged: applyWhiteContent()

  Connections {
    target: Color
    function onShellValuesChanged() { root.applyWhiteContent() }
    function onForegroundChanged() { root.applyWhiteContent() }
    function onBackgroundChanged() { root.applyWhiteContent() }
  }

  Connections {
    target: Color.bar
    function onTextChanged() { root.applyWhiteContent() }
  }

  Connections {
    target: root.bar
    function onTransparentForegroundChanged() { root.applyWhiteContent() }
    function onThemeForegroundChanged() { root.applyWhiteContent() }
  }

  Timer {
    interval: 50
    running: true
    repeat: false
    onTriggered: root.applyWhiteContent()
  }

  FileView {
    path: root.userConfigPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyShellFile(text())
    onFileChanged: reload()
  }

  Process {
    id: barHiddenProbe
    running: true
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: SplitParser {
      onRead: function(line) { root.barOffFlag = String(line).trim() === "yes" }
    }
  }

  FileView {
    path: root.toggleDir
    watchChanges: true
    printErrors: false
    onFileChanged: barHiddenProbe.running = true
  }

  Process {
    id: layersProbe
    command: ["hyprctl", "layers", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyLayers(text)
    }
  }

  Timer {
    interval: 2000
    running: root.bar === null
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (root.bar !== null) {
        root.layersBarVisible = true
        return
      }
      if (!layersProbe.running) layersProbe.running = true
    }
  }

  function callPanel(method) {
    var host = shell && shell.bar
    if (!host) return false
    if (method === "open" && typeof host.summonBarWidget === "function")
      return host.summonBarWidget(pluginId) === true
    if (method === "close" && typeof host.hideBarWidget === "function")
      return host.hideBarWidget(pluginId) === true
    if (method === "toggle") {
      var open = typeof host.isBarWidgetOpen === "function" && host.isBarWidgetOpen(pluginId)
      if (open) return host.hideBarWidget(pluginId) === true
      return host.summonBarWidget(pluginId) === true
    }
    return false
  }

  IpcHandler {
    target: "bar-glow"

    function status(): string {
      return JSON.stringify({
        id: root.pluginId,
        enabled: root.settingsEnabled,
        shown: root.glowShown,
        followTheme: root.followTheme,
        forceWhite: root.forceWhite,
        glow: root.colorHex(root.glowBase),
        position: root.configPosition,
        barHidden: root.barHidden,
        barSize: root.liveBarSize,
        size: root.glowSize,
        opacity: root.peakOpacity,
        content: root.colorHex(root.contentColor),
        barText: Color.bar ? root.colorHex(Color.bar.text) : "",
        transparentForeground: root.bar ? root.colorHex(root.bar.transparentForeground) : "",
        namespace: "omarchy-bar-glow"
      })
    }

    function open(): void { root.callPanel("open") }
    function close(): void { root.callPanel("close") }
    function show(): void { root.callPanel("open") }
    function hide(): void { root.callPanel("close") }
    function toggle(): void { root.callPanel("toggle") }
  }

  Component.onDestruction: restoreContentColor()

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: glowWindow

        required property var modelData

        screen: modelData
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        surfaceFormat.opaque: false

        readonly property string edge: root.configPosition
        readonly property bool edgeVertical: edge === "left" || edge === "right"
        readonly property int barPx: root.liveBarSize
        readonly property int bloomPx: root.glowSize
        readonly property int span: barPx + bloomPx

        visible: root.glowShown && span > 0 && !remapGuard.remapping
        implicitWidth: edgeVertical ? span : 0
        implicitHeight: edgeVertical ? 0 : span

        anchors {
          top: edge === "top" || edgeVertical
          bottom: edge === "bottom" || edgeVertical
          left: edge === "left" || !edgeVertical
          right: edge === "right" || !edgeVertical
        }

        ScreenMoveRemap {
          id: remapGuard
          window: glowWindow
        }

        // Bottom sits above the wallpaper and below the Top bar, so the wash
        // shows through the transparent bar without covering widgets.
        WlrLayershell.namespace: "omarchy-bar-glow"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {}

        GlowBand {
          anchors.fill: parent
          edge: glowWindow.edge
          barSpan: glowWindow.barPx
          glowSize: glowWindow.bloomPx
          base: root.glowBase
          peak: root.peakOpacity
          opacity: root.glowShown ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
      }
    }
  }
}
