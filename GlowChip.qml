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

  readonly property var glowService: {
    var api = bar && bar.shell
    if (!api || typeof api.serviceFor !== "function") return null
    return api.serviceFor(root.moduleName)
  }
  readonly property bool tintChip: {
    var src = glowService && glowService.liveSettings ? glowService.liveSettings : settings
    return Settings.snapshot(src).tintChip === true
  }
  readonly property color tintColor: glowService && glowService.glowBase
    ? glowService.glowBase
    : (Settings.normalizeHex(Settings.snapshot(settings).color) || "#000000")

  function noteExternal(entry) {
    var snap = Settings.snapshot(entry)
    committedJson = JSON.stringify(snap)
    committedAt = Date.now()
    root.settings = snap
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

  onBarChanged: injectPanel()
  onSettingsChanged: {
    var incoming = JSON.stringify(Settings.snapshot(settings))
    if (committedJson && incoming !== committedJson && (Date.now() - committedAt) < 500) {
      var keep = JSON.parse(committedJson)
      keep.id = root.moduleName
      root.settings = keep
      return
    }
    injectPanel()
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
    foreground: root.tintChip ? root.tintColor : (bar ? bar.barForeground : Color.foreground)
    tooltipText: root.opened ? "Close bar glow" : "Bar glow"
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.togglePanel()
    }
  }
}
