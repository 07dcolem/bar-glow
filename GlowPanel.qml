pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Settings.js" as Settings

Panel {
  id: root
  moduleName: "bar-glow"
  ipcTarget: "bar-glow"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
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

  property var pending: ({})
  property bool persistQueued: false

  function mergePending(values) {
    var next = {}
    var key
    for (key in pending) next[key] = pending[key]
    for (key in values) next[key] = values[key]
    pending = next

    var entry = Settings.snapshot(settings)
    for (key in values) entry[key] = values[key]
    entry.id = Settings.PLUGIN_ID
    settings = entry
    if (hostWidget && "settings" in hostWidget) hostWidget.settings = entry

    persistTimer.restart()
  }

  function persistNow() {
    persistTimer.stop()
    var values = pending
    pending = ({})
    if (!values || Object.keys(values).length === 0) return
    if (!bar || !bar.shell || typeof bar.shell.mutateShellConfig !== "function") return
    bar.shell.mutateShellConfig(function(config) {
      Settings.writeEntries(config, Settings.PLUGIN_ID, values)
    })
  }

  function setEnabled(on) { mergePending({ enabled: on === true }) }
  function setFollowTheme(on) { mergePending({ followTheme: on === true }) }
  function setForceGlyphs(on) { mergePending({ forceWhite: on === true }) }
  function setBloom(px) { mergePending({ size: Settings.sizeValue(px, live.size) }) }
  function setOpacity(value) { mergePending({ opacity: Settings.opacityValue(value, live.opacity) }) }
  function setGlowColor(hex) {
    mergePending({ followTheme: false, color: Settings.normalizeHex(hex) || live.color })
  }
  function setGlyphColor(hex) {
    mergePending({
      followTheme: false,
      forceWhite: true,
      contentColor: Settings.normalizeHex(hex) || live.contentColor
    })
  }
  function applyThemeColors() {
    mergePending({
      followTheme: true,
      forceWhite: true,
      color: "theme",
      contentColor: "theme"
    })
  }

  function open() { root.controller.show() }
  function close() { persistNow(); root.controller.hide() }
  function toggle() { opened ? close() : open() }

  Timer {
    id: persistTimer
    interval: 90
    repeat: false
    onTriggered: root.persistNow()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(body.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: glowPicker.editing || glyphPicker.editing
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

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
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            iconComponent: glowIcon
            trailingControl: enabledSwitch
          }

          Component {
            id: glowIcon
            Text {
              text: "󰃝"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.display
            }
          }

          Component {
            id: enabledSwitch
            ToggleSwitch {
              checked: root.glowOn
              foreground: root.contentForeground
              accent: Color.accent
              onToggled: root.setEnabled(!root.glowOn)
            }
          }

          Button {
            width: parent.width
            text: "Use theme colors"
            iconText: "󰏘"
            foreground: root.contentForeground
            bordered: true
            onClicked: root.applyThemeColors()
          }

          Text {
            width: parent.width
            visible: root.followTheme
            text: "Glow and glyphs track Color.background / Color.foreground. Picking a custom color turns this off."
            wrapMode: Text.WordWrap
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }

          PanelSeparator { foreground: root.contentForeground }

          PanelSectionHeader {
            text: "GLOW"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
          }

          RowLayout {
            width: parent.width
            Text {
              text: "Opacity"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              Layout.fillWidth: true
            }
            Text {
              text: Math.round(root.opacityValue * 100) + "%"
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            minimum: 0.2
            maximum: 1
            step: 0.02
            value: root.opacityValue
            onMoved: function(v) { root.setOpacity(v) }
          }

          RowLayout {
            width: parent.width
            Text {
              text: "Bloom"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              Layout.fillWidth: true
            }
            Text {
              text: root.bloomPx + " px"
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            minimum: 0
            maximum: 40
            step: 1
            integer: true
            value: root.bloomPx
            onMoved: function(v) { root.setBloom(v) }
          }

          ColorPicker {
            id: glowPicker
            width: parent.width
            label: "Glow color"
            value: root.glowHex
            followTheme: root.followTheme
            foreground: root.contentForeground
            presets: ["#000000", "#111111", "#1c1c1c", "#2b2b2b", Settings.colorToHex(Color.background), Settings.colorToHex(Color.accent)]
            onColorPicked: function(hex) { root.setGlowColor(hex) }
          }

          PanelSeparator { foreground: root.contentForeground }

          PanelSectionHeader {
            text: "GLYPHS"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
          }

          Toggle {
            width: parent.width
            label: "Force glyph color"
            description: "Override the wallpaper-sampled bar text so icons stay readable on the glow."
            checked: root.forceGlyphs
            foreground: root.contentForeground
            accent: Color.accent
            onClicked: root.setForceGlyphs(!root.forceGlyphs)
          }

          ColorPicker {
            id: glyphPicker
            width: parent.width
            label: "Glyph color"
            value: root.glyphHex
            followTheme: root.followTheme
            interactive: root.forceGlyphs
            foreground: root.contentForeground
            presets: ["#ffffff", "#f5f5f5", "#e6e6e6", "#d0d0d0", Settings.colorToHex(Color.foreground), Settings.colorToHex(Color.accent)]
            onColorPicked: function(hex) { root.setGlyphColor(hex) }
          }
        }
      }
    }
  }
}
