pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Settings.js" as Settings

Panel {
  id: panel
  moduleName: "bar-glow"
  ipcTarget: "bar-glow"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  // The overlay loader injects the scoped plugin shell. The chip path leaves
  // this null and persists through hostWidget instead.
  property var shell: null
  property var glowService: null
  property int serviceBindAttempts: 0
  property string committedJson: ""
  property double committedAt: 0
  readonly property var barIdentity: hostWidget || panel
  readonly property color contentForeground: bar ? bar.foreground : Color.popups.text
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var live: Settings.snapshot(settings)
  readonly property bool glowOn: live.enabled
  readonly property bool followTheme: live.followTheme
  readonly property bool forceGlyphs: live.forceWhite
  readonly property int bloomPx: live.size
  readonly property real opacityValue: live.opacity
  readonly property string glowHex: followTheme ? Settings.colorToHex(Color.background) : Settings.normalizeHex(live.color) || "#000000"
  readonly property string glyphHex: followTheme ? Settings.colorToHex(Color.foreground) : Settings.normalizeHex(live.contentColor) || "#ffffff"

  property var pending: null

  // Toggles commit immediately so the glow and glyphs update on the click.
  // Sliders and color drags coalesce into one shell.json write.
  function stage(values, immediate) {
    var entry = Settings.snapshot(settings)
    var key
    for (key in values) entry[key] = values[key]
    entry.id = Settings.PLUGIN_ID
    pending = entry
    settings = entry
    if (immediate) persistNow()
    else persistTimer.restart()
  }

  function shellApi() {
    if (bar && bar.shell) return bar.shell
    return shell
  }

  function resolveService() {
    var api = shellApi()
    if (!api || typeof api.serviceFor !== "function") return null
    var svc = api.serviceFor(Settings.PLUGIN_ID)
    return svc || null
  }

  function bindService() {
    if (hostWidget) return
    var svc = resolveService()
    if (svc !== glowService) glowService = svc
    if (svc) {
      serviceBindAttempts = 0
      adoptFromService()
      return
    }
    if (serviceBindAttempts >= 5) return
    serviceBindAttempts += 1
    Qt.callLater(bindService)
  }

  // The chip pushes settings itself. The overlay has no host, so the panel
  // follows the service snapshot, which already includes a click's live override.
  function adoptFromService() {
    if (hostWidget || pending) return
    var svc = glowService || resolveService()
    if (!svc || !svc.liveSettings) return
    var incoming = Settings.snapshot(svc.liveSettings)
    var incomingJson = JSON.stringify(incoming)
    if (committedJson && incomingJson !== committedJson && (Date.now() - committedAt) < 500)
      return
    if (JSON.stringify(Settings.snapshot(settings)) === incomingJson) return
    settings = incoming
  }

  function persistNow() {
    persistTimer.stop()
    var entry = pending
    pending = null
    if (!entry) return
    var snap = Settings.snapshot(entry)
    committedJson = JSON.stringify(snap)
    committedAt = Date.now()
    if (hostWidget && typeof hostWidget.commitSettings === "function") {
      hostWidget.commitSettings(entry)
      return
    }
    var api = shellApi()
    if (api && typeof api.serviceFor === "function") {
      var svc = api.serviceFor(Settings.PLUGIN_ID)
      if (svc && typeof svc.applyLive === "function") svc.applyLive(snap)
    }
    if (api && typeof api.updateEntryInline === "function")
      api.updateEntryInline(Settings.PLUGIN_ID, entry)
  }

  function setEnabled(on) { stage({ enabled: on === true }, true) }
  function setFollowTheme(on) { stage({ followTheme: on === true }, true) }
  function setForceGlyphs(on) { stage({ forceWhite: on === true }, true) }
  function setBloom(px) { stage({ size: Settings.sizeValue(px, live.size) }, false) }
  function setOpacity(value) { stage({ opacity: Settings.opacityValue(value, live.opacity) }, false) }
  function setGlowColor(hex) {
    stage({ followTheme: false, color: Settings.normalizeHex(hex) || live.color }, false)
  }
  function setGlyphColor(hex) {
    stage({
      followTheme: false,
      forceWhite: true,
      contentColor: Settings.normalizeHex(hex) || live.contentColor
    }, false)
  }
  function applyThemeColors() {
    stage({
      followTheme: true,
      forceWhite: true,
      color: "theme",
      contentColor: "theme"
    }, true)
  }

  function open() {
    if (!hostWidget) adoptFromService()
    panel.controller.show()
  }

  onShellChanged: bindService()
  onHostWidgetChanged: {
    if (!hostWidget && shell) bindService()
  }

  Connections {
    target: panel.glowService
    function onLiveSettingsChanged() { panel.adoptFromService() }
  }
  function close() { persistNow(); panel.controller.hide() }
  function toggle() { opened ? close() : open() }

  Timer {
    id: persistTimer
    interval: 90
    repeat: false
    onTriggered: panel.persistNow()
  }

  KeyboardPanel {
    id: keyboard
    anchorItem: panel.anchorItem
    owner: panel.barIdentity
    bar: panel.bar
    open: panel.opened
    focusTarget: keyCatcher
    contentWidth: keyboard.fittedContentWidth(Style.space(380))
    contentHeight: keyboard.fittedContentHeight(body.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: glowPicker.editing || glyphPicker.editing
      onCloseRequested: panel.close()
      onTabRequested: function(direction) { panel.switchPanel(direction) }

      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: body
          width: scroller.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Bar Glow"
            meta: followTheme ? "Following the active theme" : "Custom colors"
            detail: glowOn ? "On" : "Off"
            foreground: panel.contentForeground
            fontFamily: panel.contentFontFamily
            iconComponent: glowIcon
            trailingControl: enabledSwitch
          }

          Component {
            id: glowIcon
            Text {
              text: "󰃝"
              color: panel.contentForeground
              font.family: panel.contentFontFamily
              font.pixelSize: Style.font.display
            }
          }

          // PanelHero's own id is `root`. Bind the switch through `panel` so the
          // knob tracks this panel and the click reaches setEnabled.
          Component {
            id: enabledSwitch
            ToggleSwitch {
              checked: panel.glowOn
              foreground: panel.contentForeground
              accent: Color.accent
              onToggled: panel.setEnabled(!panel.glowOn)
            }
          }

          Button {
            width: parent.width
            text: "Use theme colors"
            iconText: "󰏘"
            foreground: panel.contentForeground
            bordered: true
            onClicked: panel.applyThemeColors()
          }

          Text {
            width: parent.width
            visible: panel.followTheme
            text: "Glow and glyphs track Color.background / Color.foreground. Picking a custom color turns this off."
            wrapMode: Text.WordWrap
            color: Qt.darker(panel.contentForeground, 1.4)
            font.family: panel.contentFontFamily
            font.pixelSize: Style.font.caption
          }

          PanelSeparator { foreground: panel.contentForeground }

          PanelSectionHeader {
            text: "GLOW"
            foreground: panel.contentForeground
            fontFamily: panel.contentFontFamily
          }

          RowLayout {
            width: parent.width
            Text {
              text: "Opacity"
              color: panel.contentForeground
              font.family: panel.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              Layout.fillWidth: true
            }
            Text {
              text: Math.round(panel.opacityValue * 100) + "%"
              color: Qt.darker(panel.contentForeground, 1.4)
              font.family: panel.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          PanelSlider {
            width: parent.width
            bar: panel.bar
            minimum: 0.2
            maximum: 1
            step: 0.02
            value: panel.opacityValue
            onMoved: function(v) { panel.setOpacity(v) }
          }

          RowLayout {
            width: parent.width
            Text {
              text: "Bloom"
              color: panel.contentForeground
              font.family: panel.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              Layout.fillWidth: true
            }
            Text {
              text: panel.bloomPx + " px"
              color: Qt.darker(panel.contentForeground, 1.4)
              font.family: panel.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          PanelSlider {
            width: parent.width
            bar: panel.bar
            minimum: 0
            maximum: 40
            step: 1
            integer: true
            value: panel.bloomPx
            onMoved: function(v) { panel.setBloom(v) }
          }

          ColorPicker {
            id: glowPicker
            width: parent.width
            label: "Glow color"
            value: panel.glowHex
            followTheme: panel.followTheme
            foreground: panel.contentForeground
            fontFamily: panel.contentFontFamily
            presets: ["#000000", "#111111", "#1c1c1c", "#2b2b2b", Settings.colorToHex(Color.background), Settings.colorToHex(Color.accent)]
            onColorPicked: function(hex) { panel.setGlowColor(hex) }
          }

          PanelSeparator { foreground: panel.contentForeground }

          PanelSectionHeader {
            text: "GLYPHS"
            foreground: panel.contentForeground
            fontFamily: panel.contentFontFamily
          }

          Toggle {
            width: parent.width
            label: "Force glyph color"
            description: "Override the wallpaper-sampled bar text so icons stay readable on the glow."
            checked: panel.forceGlyphs
            foreground: panel.contentForeground
            accent: Color.accent
            onClicked: panel.setForceGlyphs(!panel.forceGlyphs)
          }

          ColorPicker {
            id: glyphPicker
            width: parent.width
            label: "Glyph color"
            value: panel.glyphHex
            followTheme: panel.followTheme
            interactive: panel.forceGlyphs
            foreground: panel.contentForeground
            fontFamily: panel.contentFontFamily
            presets: ["#ffffff", "#f5f5f5", "#e6e6e6", "#d0d0d0", Settings.colorToHex(Color.foreground), Settings.colorToHex(Color.accent)]
            onColorPicked: function(hex) { panel.setGlyphColor(hex) }
          }
        }
      }
    }
  }
}
