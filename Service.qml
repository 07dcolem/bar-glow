import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Settings.js" as Settings

// Full-width glow behind the stock Omarchy bar. Not a bar replacement.
// Settings come from the plugin shell's barConfig (the published bar object).
// shell.shellConfig is not on that object, so reading it always fell back to
// defaults and toggles never reached this window. Glyph color is applied by
// GlowChip, which holds the real bar; this service only draws the wash.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string pluginId: (manifest && manifest.id) ? String(manifest.id) : "bar-glow"
  readonly property color white: Qt.rgba(1, 1, 1, 1)

  readonly property var bar: shell && shell.bar ? shell.bar : null

  // The panel pushes the new snapshot here in the same click. A shell.json
  // write can reload a stale copy and bounce barConfig; this override stays
  // until that published config catches up.
  property var liveOverride: null
  readonly property var configEntry: Settings.findEntry(shell ? shell.barConfig : null, pluginId)
  readonly property var pluginEntry: liveOverride ? liveOverride : configEntry
  readonly property var liveSettings: Settings.snapshot(pluginEntry)

  function applyLive(entry) {
    liveOverride = Settings.snapshot(entry)
  }

  onConfigEntryChanged: {
    if (!liveOverride) return
    if (JSON.stringify(Settings.snapshot(configEntry)) === JSON.stringify(liveOverride))
      liveOverride = null
  }

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

  function colorHex(value) {
    if (!value) return "#000000"
    var c = value
    if (typeof c === "string") c = Qt.color(c)
    if (!c) return "#000000"
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
    return "top"
  }

  readonly property bool vertical: configPosition === "left" || configPosition === "right"
  readonly property int liveBarSize: {
    if (bar && bar.barSize > 0) return bar.barSize
    return vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  }

  readonly property bool barHidden: bar && bar.barHidden === true

  readonly property bool glowShown: settingsEnabled && !barHidden
    && liveBarSize > 0 && peakOpacity > 0

  function callPanel(method) {
    if (!shell) return false
    if (method === "open" && typeof shell.summon === "function")
      return shell.summon(pluginId, "") === true
    if (method === "close" && typeof shell.hide === "function")
      return shell.hide(pluginId) === true
    if (method === "toggle" && typeof shell.toggle === "function")
      return shell.toggle(pluginId, "") === true
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
        namespace: "omarchy-bar-glow"
      })
    }

    function open(): void { root.callPanel("open") }
    function close(): void { root.callPanel("close") }
    function show(): void { root.callPanel("open") }
    function hide(): void { root.callPanel("close") }
    function toggle(): void { root.callPanel("toggle") }
  }

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
