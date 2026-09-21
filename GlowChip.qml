import QtQuick
import qs.Commons
import qs.Ui
import "Settings.js" as Settings

BarWidget {
  id: root
  moduleName: "bar-glow"

  readonly property bool opened: panelItem ? panelItem.opened === true : false
  readonly property bool popoutSwitchClosing: panelItem ? panelItem.popoutSwitchClosing === true : false

  property var panelItem: null
  property bool applyingGlyphs: false
  property bool holdingBarText: false
  property string savedBarText: ""
  property string committedJson: ""
  property double committedAt: 0

  function open() { if (panelItem) panelItem.open() }
  function close() { if (panelItem) panelItem.close() }
  function togglePanel() { if (panelItem) panelItem.toggle() }
  function closeForPopoutSwitch() { if (panelItem) panelItem.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    panelItem = target
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  // Third-party widgets only receive PluginBarApi, and assigning Color.bar.text
  // breaks its theme binding until the shell restarts. Replacing shellValues
  // keeps that binding and is what the bar's glyph color reads.
  function forcedGlyphHex() {
    var snap = Settings.snapshot(settings)
    if (!(snap.enabled && snap.forceWhite)) return ""
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

  function applyGlyphs() {
    if (applyingGlyphs) return
    applyingGlyphs = true
    var hex = forcedGlyphHex()
    var src = Color.shellValues || {}
    var current = typeof src["bar.text"] === "string" ? src["bar.text"] : ""
    if (hex) {
      if (!sameColor(current, hex)) {
        savedBarText = current
        holdingBarText = true
        var next = copyShellValues()
        next["bar.text"] = hex
        Color.shellValues = next
      }
    } else if (holdingBarText) {
      var restore = copyShellValues()
      if (savedBarText) restore["bar.text"] = savedBarText
      else delete restore["bar.text"]
      holdingBarText = false
      savedBarText = ""
      Color.shellValues = restore
    }
    applyingGlyphs = false
  }

  function commitSettings(values) {
    var entry = Settings.snapshot(settings)
    var key
    for (key in values) entry[key] = values[key]
    entry.id = root.moduleName
    var snap = Settings.snapshot(entry)
    committedJson = JSON.stringify(snap)
    committedAt = Date.now()
    root.settings = entry
    applyGlyphs()
    var api = root.bar && root.bar.shell
    if (api && typeof api.serviceFor === "function") {
      var svc = api.serviceFor(root.moduleName)
      if (svc && typeof svc.applyLive === "function") svc.applyLive(snap)
    }
    if (api && typeof api.updateEntryInline === "function")
      api.updateEntryInline(root.moduleName, entry)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: {
    injectPanel()
    applyGlyphs()
  }
  onSettingsChanged: {
    var incoming = JSON.stringify(Settings.snapshot(settings))
    if (committedJson && incoming !== committedJson && (Date.now() - committedAt) < 500) {
      var keep = JSON.parse(committedJson)
      keep.id = root.moduleName
      root.settings = keep
      return
    }
    injectPanel()
    applyGlyphs()
  }

  Connections {
    target: Color
    function onForegroundChanged() { root.applyGlyphs() }
    function onShellValuesChanged() { root.applyGlyphs() }
  }

  Component.onCompleted: Qt.callLater(root.applyGlyphs)
  Component.onDestruction: {
    if (!root.holdingBarText) return
    root.holdingBarText = false
    var restore = root.copyShellValues()
    if (root.savedBarText) restore["bar.text"] = root.savedBarText
    else delete restore["bar.text"]
    Color.shellValues = restore
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("GlowPanel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰃝"
    tooltipText: root.opened ? "Close bar glow" : "Bar glow"
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.togglePanel()
    }
  }
}
