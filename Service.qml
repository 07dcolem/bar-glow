import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Settings.js" as Settings

// Full-width glow behind the stock Omarchy bar. Not a bar replacement.
// The published barConfig is the bar object only, so plugins[] is read from
// the user shell.json. findEntry lets the bar layout win when the chip is
// present. Glyph color is applied here, including when the chip is hidden.
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
  property bool userShellReady: false
  property var userShellConfig: null

  // barConfig is only the bar object, so a chip-less entry in plugins[] is
  // invisible there. Once shell.json has loaded, it is the only source:
  // findEntry lets the bar layout win when the chip is present.
  readonly property string shellConfigPath: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
  readonly property var configSource: {
    if (userShellReady && userShellConfig) return userShellConfig
    var barPart = shell && shell.barConfig ? shell.barConfig : null
    return barPart ? { bar: barPart, plugins: [] } : null
  }
  readonly property var configEntry: Settings.findEntry(configSource, pluginId)
  readonly property bool glyphsReady: userShellReady
    || (configEntry && String(configEntry.id || "") === pluginId)
  readonly property var pluginEntry: liveOverride ? liveOverride : configEntry
  readonly property var liveSettings: Settings.snapshot(pluginEntry)

  property real sampledLuma: -1
  property int sunsetKelvin: 0
  property bool sampleBusy: false
  property string sampleNote: ""
  property string lastWallpaperPath: ""
  property bool sampleApply: false
  property bool sampleQueued: false
  property bool sampleApplyQueued: false
  property int sampleGeneration: 0
  property string sampleScreenName: ""
  property bool watchReady: false
  property bool followWasOn: false
  property bool contrastWasOn: false
  property bool flourishArmed: false
  property bool bandReady: false

  readonly property string backgroundLink: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
  readonly property bool colorAnimated: bandReady && (followTheme || flourishArmed)

  signal settingsPushed(string json)

  function applyLive(entry) {
    liveOverride = Settings.snapshot(entry)
  }

  function ingestShellText(raw) {
    var parsed = null
    var text = String(raw || "")
    if (text.length > 2000000) {
      userShellConfig = null
      userShellReady = true
      return
    }
    try {
      parsed = JSON.parse(text)
    } catch (e) {
      parsed = null
    }
    userShellConfig = (parsed && typeof parsed === "object") ? parsed : null
    userShellReady = true
  }

  onConfigEntryChanged: {
    if (!liveOverride) return
    if (JSON.stringify(Settings.snapshot(configEntry)) === JSON.stringify(liveOverride))
      liveOverride = null
  }

  // Third-party widgets must not assign Color.bar.text: that breaks the theme
  // binding until the shell restarts. Copy shellValues and set "bar.text".
  // One owner, so the chip and this service cannot write the same override.
  property bool applyingGlyphs: false
  property bool releasingGlyphs: false
  property bool holdingBarText: false
  property string savedBarText: ""
  property string appliedGlyphHex: ""

  function forcedGlyphHex() {
    var snap = liveSettings
    if (!snap.enabled) return ""
    if (snap.autoContrast && sampledLuma >= 0)
      return Settings.contrastInkFromLuma(sampledLuma)
    if (!snap.forceWhite) return ""
    if (snap.followTheme || String(snap.contentColor) === "theme")
      return Settings.colorToHex(Color.foreground)
    return Settings.normalizeHex(snap.contentColor) || "#ffffff"
  }

  function sameColor(a, b) {
    var left = Settings.normalizeHex(a)
    var right = Settings.normalizeHex(b)
    if (left && right) return left === right
    return String(a || "") === String(b || "")
  }

  function copyShellValues() {
    var src = Color.shellValues || {}
    var next = {}
    for (var key in src) next[key] = src[key]
    return next
  }

  function restoreBarText() {
    if (!holdingBarText) return
    holdingBarText = false
    var restore = copyShellValues()
    if (savedBarText) restore["bar.text"] = savedBarText
    else delete restore["bar.text"]
    savedBarText = ""
    appliedGlyphHex = ""
    Color.shellValues = restore
  }

  function applyGlyphs() {
    if (!glyphsReady || applyingGlyphs || releasingGlyphs) return
    applyingGlyphs = true
    var hex = forcedGlyphHex()
    var src = Color.shellValues || {}
    var current = typeof src["bar.text"] === "string" ? src["bar.text"] : ""
    if (hex) {
      if (!holdingBarText) {
        savedBarText = current
        holdingBarText = true
      } else if (appliedGlyphHex && !sameColor(current, appliedGlyphHex) && !sameColor(current, hex)) {
        // A theme reload replaced bar.text under the override. Keep that
        // value so turning the force off restores the theme, not the old hex.
        savedBarText = current
      }
      appliedGlyphHex = hex
      if (!sameColor(current, hex)) {
        var next = copyShellValues()
        next["bar.text"] = hex
        Color.shellValues = next
      }
    } else {
      restoreBarText()
    }
    applyingGlyphs = false
  }

  onGlyphsReadyChanged: applyGlyphs()
  onLiveSettingsChanged: syncModes()
  onSampledLumaChanged: applyGlyphs()

  function syncModes() {
    applyGlyphs()
    if (!watchReady) return
    var follow = liveSettings.followWallpaper === true
    var contrast = liveSettings.autoContrast === true
    if (follow && !followWasOn) sampleWallpaper(true, "")
    else if (contrast && !contrastWasOn) sampleWallpaper(false, "")
    followWasOn = follow
    contrastWasOn = contrast
    if (liveSettings.nightLight === true && !nightTimer.running) refreshNight()
  }

  function flourish() {
    flourishArmed = true
    flourishTimer.restart()
  }

  function commitValues(values, animate) {
    var entry = Settings.snapshot(liveSettings)
    var key
    for (key in values) entry[key] = values[key]
    entry.id = pluginId
    var snap = Settings.snapshot(entry)
    if (animate) flourish()
    applyLive(snap)
    if (shell && typeof shell.updateEntryInline === "function")
      shell.updateEntryInline(pluginId, snap)
    settingsPushed(JSON.stringify(snap))
  }

  Connections {
    target: Color
    function onForegroundChanged() { root.applyGlyphs() }
    function onShellValuesChanged() { root.applyGlyphs() }
  }

  Component.onCompleted: Qt.callLater(function() {
    root.bandReady = true
    root.applyGlyphs()
    root.watchReady = true
    root.followWasOn = root.liveSettings.followWallpaper === true
    root.contrastWasOn = root.liveSettings.autoContrast === true
    if (root.followWasOn) root.sampleWallpaper(true, "")
    else if (root.contrastWasOn) root.sampleWallpaper(false, "")
    if (root.liveSettings.nightLight === true) root.refreshNight()
  })
  Component.onDestruction: {
    releasingGlyphs = true
    restoreBarText()
    readlinkProc.running = false
    identifyProc.running = false
    averageProc.running = false
    watchLink.running = false
    nightProbe.running = false
  }

  FileView {
    id: shellConfigFile
    path: root.shellConfigPath
    watchChanges: true
    atomicWrites: true
    printErrors: true
    onLoaded: root.ingestShellText(text())
    onLoadFailed: function(error) { root.ingestShellText("") }
    onFileChanged: reload()
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
  readonly property color storedGlow: followTheme
    ? Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 1)
    : Qt.rgba(parsedGlow.r, parsedGlow.g, parsedGlow.b, 1)
  readonly property color glowBase: {
    var hex = Settings.applyKelvin(Settings.colorToHex(storedGlow), liveSettings.nightLight ? sunsetKelvin : 0)
    var rgb = Settings.parseHexRgb(hex) || { r: storedGlow.r, g: storedGlow.g, b: storedGlow.b }
    return Qt.rgba(rgb.r, rgb.g, rgb.b, 1)
  }
  readonly property color contentColor: {
    if (liveSettings.autoContrast && sampledLuma >= 0) {
      var ink = Settings.parseHexRgb(Settings.contrastInkFromLuma(sampledLuma))
      if (ink) return Qt.rgba(ink.r, ink.g, ink.b, 1)
    }
    return followTheme ? Color.foreground : parseColor(liveSettings.contentColor, white)
  }
  readonly property real peakOpacity: Settings.effectiveOpacity(
    liveSettings.opacity, sampledLuma, liveSettings.autoContrast === true, sampledLuma >= 0)

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
        followWallpaper: root.liveSettings.followWallpaper === true,
        autoContrast: root.liveSettings.autoContrast === true,
        nightLight: root.liveSettings.nightLight === true,
        tintChip: root.liveSettings.tintChip === true,
        sampledLuma: root.sampledLuma,
        sunsetKelvin: root.sunsetKelvin,
        sampleNote: root.sampleNote,
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

  function acceptPath(value) {
    var text = String(value || "").replace(/[\r\n\0]/g, "")
    if (!text || text.length > 4096 || text.charAt(0) !== "/") return ""
    return text
  }

  function screenSize(name) {
    var screens = Quickshell.screens
    var chosen = null
    var wanted = String(name || "")
    if (!wanted) {
      var monitor = Hyprland.focusedMonitor
      wanted = monitor ? String(monitor.name || "") : ""
    }
    for (var i = 0; i < screens.length; i++) {
      var screen = screens[i]
      if (!screen) continue
      if (!chosen) chosen = screen
      if (wanted && String(screen.name || "") === wanted) {
        chosen = screen
        break
      }
    }
    if (!chosen) return null
    var w = Number(chosen.width || 0)
    var h = Number(chosen.height || 0)
    if (w < 2 || h < 2) return null
    return { width: w, height: h }
  }

  function sampleWallpaper(applyColors, screenName) {
    if (readlinkProc.running || identifyProc.running || averageProc.running) {
      sampleQueued = true
      if (applyColors) sampleApplyQueued = true
      return
    }
    beginSample(applyColors === true, String(screenName || ""))
  }

  function beginSample(applyColors, screenName) {
    sampleGeneration += 1
    sampleApply = applyColors
    sampleScreenName = screenName
    sampleQueued = false
    sampleApplyQueued = false
    sampleStage = "link"
    linkBuf = ""
    identifyBuf = ""
    averageBuf = ""
    sampleBusy = true
    sampleNote = ""
    sampleWatchdog.restart()
    readlinkProc.running = true
  }

  function finishSample(ok, note) {
    sampleWatchdog.stop()
    sampleBusy = false
    sampleStage = ""
    sampleNote = ok ? "" : (note || "Couldn't read the wallpaper")
    if (!sampleQueued) return
    var apply = sampleApplyQueued
    sampleQueued = false
    sampleApplyQueued = false
    beginSample(apply, sampleScreenName)
  }

  function failSample(note) {
    if (!sampleBusy) return
    console.warn("bar-glow: wallpaper sample failed at", sampleStage || "idle")
    sampleBusy = false
    sampleStage = ""
    readlinkProc.running = false
    identifyProc.running = false
    averageProc.running = false
    finishSample(false, note)
  }

  function wallpaperChanged() {
    if (!watchReady) return
    if (liveSettings.followWallpaper) sampleWallpaper(true, "")
    else if (liveSettings.autoContrast) sampleWallpaper(false, "")
  }

  function consumeLink(raw) {
    if (!sampleBusy || sampleStage !== "link") return
    var path = acceptPath(String(raw || "").trim())
    if (!path) {
      failSample("Couldn't read the wallpaper")
      return
    }
    var size = screenSize(sampleScreenName)
    if (!size) {
      failSample("Couldn't read the wallpaper")
      return
    }
    lastWallpaperPath = path
    identifyPath = path
    identifyScreenW = size.width
    identifyScreenH = size.height
    sampleStage = "identify"
    // `identify` has to be the subcommand. `magick -quiet identify` treats
    // "identify" as an image filename and fails to read the wallpaper.
    identifyProc.running = false
    identifyProc.command = ["/usr/bin/magick", "identify", "-limit", "memory", "64MiB", "-limit", "map", "128MiB", "-limit", "time", "2", "-quiet", "-format", "%w %h", path]
    Qt.callLater(function() {
      if (root.sampleStage === "identify") identifyProc.running = true
    })
  }

  function consumeSize(raw) {
    if (!sampleBusy || sampleStage !== "identify") return
    var text = String(raw || "")
    if (text.length > 80) text = text.substring(0, 80)
    var parts = text.trim().split(/\s+/)
    var crop = Settings.cropRect(parseInt(parts[0], 10), parseInt(parts[1], 10), identifyScreenW, identifyScreenH, configPosition, liveBarSize)
    if (!crop) {
      failSample("Couldn't read the wallpaper")
      return
    }
    var geom = String(crop.w) + "x" + String(crop.h) + "+" + String(crop.x) + "+" + String(crop.y)
    sampleStage = "average"
    averageProc.running = false
    averageProc.command = [
      "/usr/bin/magick", "-limit", "memory", "64MiB", "-limit", "map", "128MiB", "-limit", "time", "2", "-quiet", identifyPath,
      "-crop", geom, "+repage", "-resize", "1x1!",
      "-format", "%[fx:int(r*255+0.5)],%[fx:int(g*255+0.5)],%[fx:int(b*255+0.5)]",
      "info:"
    ]
    Qt.callLater(function() {
      if (root.sampleStage === "average") averageProc.running = true
    })
  }

  function consumeAverage(raw) {
    if (!sampleBusy || sampleStage !== "average") return
    var text = String(raw || "")
    if (text.length > 80) text = text.substring(0, 80)
    var match = text.match(/(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})/)
    if (!match) {
      failSample("Couldn't read the wallpaper")
      return
    }
    var r = Number(match[1])
    var g = Number(match[2])
    var b = Number(match[3])
    var hex = Settings.colorToHex({ r: r / 255, g: g / 255, b: b / 255 })
    sampledLuma = Settings.relativeLuminance(r / 255, g / 255, b / 255)
    var apply = sampleApply
    if (apply) {
      commitValues({
        followTheme: false,
        forceWhite: true,
        color: hex,
        contentColor: Settings.contrastInk(hex)
      }, true)
    }
    finishSample(true, "")
  }

  function refreshNight() {
    if (!nightProbe.running) nightProbe.running = true
  }

  function pushLink(chunk) {
    var next = linkBuf + String(chunk || "")
    if (next.length > 4096) {
      linkBuf = ""
      failSample("Couldn't read the wallpaper")
      readlinkProc.running = false
      return
    }
    linkBuf = next
  }

  function pushIdentify(chunk) {
    var next = identifyBuf + String(chunk || "")
    if (next.length > 64) {
      identifyBuf = ""
      failSample("Couldn't read the wallpaper")
      identifyProc.running = false
      return
    }
    identifyBuf = next
  }

  function pushAverage(chunk) {
    var next = averageBuf + String(chunk || "")
    if (next.length > 32) {
      averageBuf = ""
      failSample("Couldn't read the wallpaper")
      averageProc.running = false
      return
    }
    averageBuf = next
  }

  function pushWatch(chunk) {
    var next = watchBuf + String(chunk || "")
    if (next.length > 4096) {
      watchBuf = ""
      watchLink.running = false
      return
    }
    watchBuf = next
  }

  function pushNight(chunk) {
    var next = nightBuf + String(chunk || "")
    if (next.length > 64) {
      nightBuf = ""
      nightProbe.running = false
      return
    }
    nightBuf = next
  }

  property string sampleStage: ""
  property string linkBuf: ""
  property string identifyBuf: ""
  property string averageBuf: ""
  property string watchBuf: ""
  property string nightBuf: ""
  property string identifyPath: ""
  property real identifyScreenW: 0
  property real identifyScreenH: 0

  Timer {
    id: flourishTimer
    interval: 460
    onTriggered: root.flourishArmed = false
  }

  Timer {
    id: sampleWatchdog
    interval: 4000
    onTriggered: root.failSample("Couldn't read the wallpaper")
  }

  Timer {
    id: nightTimer
    interval: 20000
    repeat: true
    running: root.liveSettings.nightLight === true
    onTriggered: root.refreshNight()
  }

  Timer {
    id: wallpaperPoll
    interval: 3000
    repeat: true
    running: root.watchReady && (root.liveSettings.followWallpaper === true || root.liveSettings.autoContrast === true)
    onTriggered: if (!watchLink.running && !root.sampleBusy) watchLink.running = true
  }

  Process {
    id: readlinkProc
    command: ["/usr/bin/readlink", "-f", root.backgroundLink]
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.pushLink(chunk) }
    }
    onExited: function(code) {
      var text = root.linkBuf
      root.linkBuf = ""
      if (root.sampleStage !== "link") return
      if (code !== 0) {
        root.failSample("Couldn't read the wallpaper")
        return
      }
      root.consumeLink(text)
    }
  }

  Process {
    id: identifyProc
    command: ["/usr/bin/magick", "-version"]
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.pushIdentify(chunk) }
    }
    onExited: function(code) {
      var text = root.identifyBuf
      root.identifyBuf = ""
      if (root.sampleStage !== "identify") return
      if (code !== 0) {
        root.failSample("Couldn't read the wallpaper")
        return
      }
      root.consumeSize(text)
    }
  }

  Process {
    id: averageProc
    command: ["/usr/bin/magick", "-version"]
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.pushAverage(chunk) }
    }
    onExited: function(code) {
      var text = root.averageBuf
      root.averageBuf = ""
      if (root.sampleStage !== "average") return
      if (code !== 0) {
        root.failSample("Couldn't read the wallpaper")
        return
      }
      root.consumeAverage(text)
    }
  }

  Process {
    id: watchLink
    command: ["/usr/bin/readlink", "-f", root.backgroundLink]
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.pushWatch(chunk) }
    }
    onExited: function(code) {
      var text = root.watchBuf
      root.watchBuf = ""
      if (code !== 0) return
      var path = root.acceptPath(String(text || "").trim())
      if (path && path !== root.lastWallpaperPath) root.wallpaperChanged()
    }
  }

  Process {
    id: nightProbe
    command: ["/usr/bin/hyprctl", "hyprsunset", "temperature"]
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.pushNight(chunk) }
    }
    onExited: function(code) {
      var text = root.nightBuf
      root.nightBuf = ""
      if (code !== 0) {
        root.sunsetKelvin = 0
        return
      }
      var match = String(text || "").match(/[0-9]+/)
      root.sunsetKelvin = match ? Number(match[0]) : 0
    }
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
          animateColor: root.colorAnimated
          opacity: root.glowShown ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
      }
    }
  }
}
