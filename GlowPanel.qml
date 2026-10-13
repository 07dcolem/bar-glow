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
  readonly property bool followWallpaper: live.followWallpaper
  readonly property bool forceGlyphs: live.forceWhite
  readonly property bool autoContrast: live.autoContrast
  readonly property bool nightLight: live.nightLight
  readonly property bool tintChip: live.tintChip
  readonly property int bloomPx: live.size
  readonly property real opacityValue: live.opacity
  readonly property string glowHex: followTheme ? Settings.colorToHex(Color.background) : Settings.normalizeHex(live.color) || "#000000"
  readonly property string glyphHex: followTheme ? Settings.colorToHex(Color.foreground) : Settings.normalizeHex(live.contentColor) || "#ffffff"
  readonly property bool haveSample: glowService && glowService.sampledLuma >= 0
  readonly property string displayGlyphHex: autoContrast && haveSample
    ? Settings.contrastInkFromLuma(glowService.sampledLuma)
    : glyphHex
  readonly property string displayGlowHex: {
    var kelvin = nightLight && glowService ? glowService.sunsetKelvin : 0
    return Settings.applyKelvin(glowHex, kelvin)
  }
  readonly property string heroMeta: followWallpaper
    ? "Following the wallpaper"
    : (followTheme ? "Following the active theme" : "Custom colors")

  readonly property var cursorRows: {
    var rows = ["power", "theme", "undo", "opacity", "bloom", "glow", "force", "glyph",
      "subtle", "strong", "accent", "themeOnly"]
    var customs = live.customPresets || []
    for (var i = 0; i < customs.length; i++) rows.push("custom:" + i)
    rows.push("save", "sample", "follow", "contrast", "night", "chip")
    return rows
  }
  property int cursor: 0
  readonly property string cursorId: {
    var rows = cursorRows
    if (!rows.length) return ""
    var i = cursor
    if (i < 0) i = 0
    if (i >= rows.length) i = rows.length - 1
    return rows[i]
  }

  property bool pickerOpen: false
  property string pickerTarget: "glow"
  property real pickerY: 0
  property bool saving: false
  property var undoStack: []
  property bool undoGesture: false
  property bool dragGlow: false
  property bool applyingUndo: false
  property string preSampleJson: ""
  readonly property bool canUndo: undoStack.length > 0

  property var pending: null

  function settingsJson() {
    return JSON.stringify(Settings.snapshot(settings))
  }

  function rememberUndo() {
    if (applyingUndo) return
    if (undoGesture) return
    var current = settingsJson()
    var stack = undoStack.slice()
    if (!stack.length || stack[stack.length - 1] !== current) stack.push(current)
    if (stack.length > 40) stack = stack.slice(stack.length - 40)
    undoStack = stack
    undoGesture = true
  }

  function endUndoGesture() {
    var shouldRipple = dragGlow && !applyingUndo
    dragGlow = false
    undoGesture = false
    if (shouldRipple && panelBloom) panelBloom.pulse()
  }

  function stage(values, immediate) {
    if (immediate) {
      dragGlow = false
      endUndoGesture()
    }
    rememberUndo()
    var entry = Settings.snapshot(settings)
    var key
    for (key in values) entry[key] = values[key]
    entry.id = Settings.PLUGIN_ID
    pending = entry
    settings = entry
    if (immediate) {
      persistNow()
      undoGestureTimer.stop()
      endUndoGesture()
      if (panelBloom) panelBloom.pulse()
    } else {
      dragGlow = true
      if (panelBloom) panelBloom.bump()
      persistTimer.restart()
      undoGestureTimer.restart()
    }
  }

  function applySnapshot(json) {
    var entry = null
    try { entry = JSON.parse(String(json || "")) } catch (e) { entry = null }
    if (!entry) return
    entry = Settings.snapshot(entry)
    entry.id = Settings.PLUGIN_ID
    applyingUndo = true
    endUndoGesture()
    pending = entry
    settings = entry
    persistNow()
    applyingUndo = false
  }

  function undo() {
    if (!canUndo) return
    var stack = undoStack.slice()
    var previous = stack.pop()
    undoStack = stack
    preSampleJson = ""
    applySnapshot(previous)
    if (panelBloom) panelBloom.pulse()
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

  function adoptPushed(json) {
    if (pending) return
    var parsed = null
    try { parsed = JSON.parse(String(json || "")) } catch (e) { parsed = null }
    if (!parsed) return
    var snap = Settings.snapshot(parsed)
    if (preSampleJson && preSampleJson !== JSON.stringify(snap)) {
      var stack = undoStack.slice()
      stack.push(preSampleJson)
      if (stack.length > 40) stack = stack.slice(stack.length - 40)
      undoStack = stack
      if (panelBloom) panelBloom.pulse()
    }
    preSampleJson = ""
    if (hostWidget && hostWidget.noteExternal) hostWidget.noteExternal(snap)
    else settings = snap
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

  function flourish() {
    var svc = resolveService() || glowService
    if (svc && svc.flourish) svc.flourish()
  }

  function screenName() {
    return keyboard.screen ? String(keyboard.screen.name || "") : ""
  }

  function setEnabled(on) { stage({ enabled: on === true }, true) }
  function setFollowWallpaper(on) {
    stage({ followWallpaper: on === true, followTheme: on === true ? false : live.followTheme }, true)
  }
  function setForceGlyphs(on) { stage({ forceWhite: on === true }, true) }
  function setAutoContrast(on) { stage({ autoContrast: on === true }, true) }
  function setNightLight(on) { stage({ nightLight: on === true }, true) }
  function setTintChip(on) { stage({ tintChip: on === true }, true) }
  function setBloom(px) { stage({ size: Settings.sizeValue(px, live.size) }, false) }
  function setOpacity(value) { stage({ opacity: Settings.opacityValue(value, live.opacity) }, false) }
  function nudgeOpacity(direction) { setOpacity(opacityValue + direction * 0.02) }
  function setGlowColor(hex) {
    stage({
      followTheme: false,
      followWallpaper: false,
      color: Settings.normalizeHex(hex) || live.color
    }, false)
  }
  function setGlyphColor(hex) {
    stage({
      followTheme: false,
      followWallpaper: false,
      forceWhite: true,
      contentColor: Settings.normalizeHex(hex) || live.contentColor
    }, false)
  }
  function applyThemeColors() {
    flourish()
    stage({
      followTheme: true,
      followWallpaper: false,
      forceWhite: true,
      color: "theme",
      contentColor: "theme"
    }, true)
  }
  function applyBuiltin(id) {
    flourish()
    if (id === "subtle") {
      stage({
        followTheme: true, followWallpaper: false, forceWhite: true,
        color: "theme", contentColor: "theme", opacity: 0.4, size: 8
      }, true)
    } else if (id === "strong") {
      stage({
        followTheme: false, followWallpaper: false, forceWhite: true,
        color: "#000000", contentColor: "#ffffff", opacity: 0.92, size: 32
      }, true)
    } else if (id === "accent") {
      stage({
        followTheme: false, followWallpaper: false, forceWhite: true,
        color: Settings.colorToHex(Color.accent),
        contentColor: Settings.colorToHex(Color.foreground),
        opacity: 0.72, size: 16
      }, true)
    } else if (id === "theme") {
      stage({
        followTheme: true, followWallpaper: false, forceWhite: true,
        color: "theme", contentColor: "theme"
      }, true)
    }
  }
  function applyCustom(index) {
    var list = live.customPresets || []
    var preset = list[index]
    if (!preset) return
    flourish()
    stage({
      size: preset.size,
      opacity: preset.opacity,
      color: preset.color,
      contentColor: preset.contentColor,
      forceWhite: preset.forceWhite,
      followTheme: preset.followTheme,
      followWallpaper: preset.followWallpaper && !preset.followTheme,
      autoContrast: preset.autoContrast,
      nightLight: preset.nightLight,
      tintChip: preset.tintChip
    }, true)
  }
  function deleteCustom(index) {
    stage({ customPresets: Settings.removePreset(live.customPresets, index) }, true)
  }
  function saveCurrent(name) {
    var preset = Settings.capturePreset(live, name)
    if (!preset) return false
    stage({ customPresets: Settings.savePreset(live.customPresets, preset) }, true)
    return true
  }
  function requestSample() {
    var svc = resolveService() || glowService
    if (!svc || !svc.sampleWallpaper) return
    endUndoGesture()
    preSampleJson = settingsJson()
    svc.sampleWallpaper(true, screenName())
  }

  function rowIndex(id) {
    var rows = cursorRows
    for (var i = 0; i < rows.length; i++) if (rows[i] === id) return i
    return cursor
  }
  function moveCursor(dy) {
    var n = cursorRows.length
    if (!n) return
    cursor = (cursor + dy + n) % n
    Qt.callLater(revealCursor)
  }
  function revealCursor() {
    var item = cursorItem()
    if (!item || scroller.height <= 0) return
    var pos = item.mapToItem(scroller.contentItem, 0, 0)
    var top = pos.y
    var bottom = top + item.height
    if (top < scroller.contentY) scroller.contentY = Math.max(0, top - Style.space(8))
    else if (bottom > scroller.contentY + scroller.height)
      scroller.contentY = Math.max(0, bottom - scroller.height + Style.space(8))
  }
  function cursorItem() {
    var id = cursorId
    if (id === "power" || id === "theme") return hero
    if (id === "opacity" || id === "bloom" || id === "glow") return glowSection
    if (id === "force" || id === "glyph") return glyphSection
    if (id === "subtle" || id === "strong" || id === "accent" || id === "themeOnly" || id.indexOf("custom:") === 0 || id === "save")
      return presetSection
    return sampleSection
  }
  function adjustCursor(dx) {
    var id = cursorId
    if (id === "opacity") nudgeOpacity(dx < 0 ? -1 : 1)
    else if (id === "bloom") setBloom(bloomPx + (dx < 0 ? -1 : 1))
    else if (id === "glow") glowRow.cycle(dx)
    else if (id === "glyph") glyphRow.cycle(dx)
  }
  function activateCursor() {
    var id = cursorId
    if (id === "power") setEnabled(!glowOn)
    else if (id === "theme") applyThemeColors()
    else if (id === "undo") undo()
    else if (id === "glow") openPicker("glow")
    else if (id === "force") setForceGlyphs(!forceGlyphs)
    else if (id === "glyph") openPicker("glyph")
    else if (id === "subtle" || id === "strong" || id === "accent" || id === "theme") applyBuiltin(id === "theme" ? "theme" : id)
    else if (id === "themeOnly") applyBuiltin("theme")
    else if (id.indexOf("custom:") === 0) applyCustom(parseInt(id.substring(7), 10))
    else if (id === "save") beginSave()
    else if (id === "sample") requestSample()
    else if (id === "follow") setFollowWallpaper(!followWallpaper)
    else if (id === "contrast") setAutoContrast(!autoContrast)
    else if (id === "night") setNightLight(!nightLight)
    else if (id === "chip") setTintChip(!tintChip)
  }
  function beginSave() {
    saving = true
    Qt.callLater(function() {
      var field = saveLoader.item
      if (field) field.forceActiveFocus()
    })
  }
  function cancelSave() {
    saving = false
    if (opened && !pickerOpen) keyCatcher.forceActiveFocus()
  }
  function commitSave(name) {
    var field = saveLoader.item
    var chosen = (name === undefined || name === null) && field ? field.editText : name
    if (!saveCurrent(chosen || "")) return
    Qt.callLater(function() {
      panel.saving = false
      if (panel.opened && !panel.pickerOpen) keyCatcher.forceActiveFocus()
    })
  }

  function openPicker(target) {
    if (target === "glyph" && !forceGlyphs) return
    pickerTarget = target
    pickerOpen = true
    Qt.callLater(placePicker)
    Qt.callLater(function() { if (pickerOpen) pickerFocus.forceActiveFocus() })
  }
  function closePicker() {
    if (!pickerOpen) return
    pickerOpen = false
    if (opened) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  function placePicker() {
    var host = pickerLayer
    var row = pickerTarget === "glyph" ? glyphRow : glowRow
    var cardH = pickerCard.implicitHeight
    if (!host || host.height <= 0) return
    var y = Math.max(0, (host.height - cardH) / 2)
    if (row) {
      var pos = row.mapToItem(host, 0, 0)
      var below = pos.y + row.height + Style.space(6)
      var above = pos.y - cardH - Style.space(6)
      if (below + cardH <= host.height) y = below
      else if (above >= 0) y = above
    }
    pickerY = y
  }

  function open() {
    if (!hostWidget) adoptFromService()
    panel.controller.show()
  }
  function close() {
    closePicker()
    cancelSave()
    persistNow()
    panel.controller.hide()
  }
  function toggle() { opened ? close() : open() }

  onShellChanged: bindService()
  onHostWidgetChanged: {
    if (!hostWidget && shell) bindService()
  }
  onOpenedChanged: {
    if (opened) {
      undoStack = []
      undoGesture = false
      preSampleJson = ""
      var svc = resolveService()
      if (svc) glowService = svc
      panelBloom.start()
    } else {
      undoStack = []
      undoGesture = false
      preSampleJson = ""
      panelBloom.stop()
      pickerOpen = false
      saving = false
    }
  }
  onCursorRowsChanged: {
    if (cursor >= cursorRows.length) cursor = Math.max(0, cursorRows.length - 1)
  }

  Connections {
    target: panel.glowService
    function onLiveSettingsChanged() { panel.adoptFromService() }
    function onSettingsPushed(json) { panel.adoptPushed(json) }
    function onSampleNoteChanged() {
      if (panel.glowService && panel.glowService.sampleNote !== "")
        panel.preSampleJson = ""
    }
  }

  Shortcut {
    sequences: [StandardKey.Undo]
    enabled: panel.opened && !panel.pickerOpen && !panel.saving
    onActivated: panel.undo()
  }

  Timer {
    id: undoGestureTimer
    interval: 280
    repeat: false
    onTriggered: panel.endUndoGesture()
  }

  // The chip path does not bind glowService in bindService. Resolve it for
  // the bloom, sampling, and the night-light reading either way.
  Timer {
    interval: 200
    running: panel.glowService === null && panel.opened
    repeat: true
    onTriggered: {
      var svc = panel.resolveService()
      if (svc) panel.glowService = svc
    }
  }

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

    PanelBloom {
      id: panelBloom
      halo: panel.displayGlowHex
      core: panel.displayGlyphHex
      z: 0
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      z: 1
      blocked: panel.pickerOpen || panel.saving
      onCloseRequested: panel.close()
      onTabRequested: function(direction) { panel.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) panel.moveCursor(dy)
        else if (dx !== 0) panel.adjustCursor(dx)
      }
      onActivateRequested: panel.activateCursor()
      onDeleteRequested: {
        if (panel.cursorId.indexOf("custom:") === 0)
          panel.deleteCustom(parseInt(panel.cursorId.substring(7), 10))
      }
      onTextKey: function(text) {
        if (text === "-" || text === "_") panel.nudgeOpacity(-1)
        else if (text === "=" || text === "+") panel.nudgeOpacity(1)
      }

      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height && !panel.pickerOpen

        Column {
          id: body
          width: scroller.width
          spacing: Style.space(8)

          PanelHero {
            id: hero
            width: parent.width
            title: "Bar Glow"
            meta: panel.heroMeta
            detail: panel.glowOn ? "On" : "Off"
            foreground: panel.contentForeground
            fontFamily: panel.contentFontFamily
            iconComponent: glowIcon
            trailingControl: enabledSwitch
          }

          Component {
            id: glowIcon
            Text {
              text: "󰃝"
              textFormat: Text.PlainText
              color: panel.tintChip ? panel.displayGlowHex : panel.contentForeground
              font.family: panel.contentFontFamily
              font.pixelSize: Style.font.display
            }
          }

          Component {
            id: enabledSwitch
            ToggleSwitch {
              checked: panel.glowOn
              foreground: panel.contentForeground
              accent: Color.accent
              hasCursor: panel.cursorId === "power"
              onToggled: panel.setEnabled(!panel.glowOn)
            }
          }

          Button {
            width: parent.width
            text: "Use theme colors"
            iconText: "󰏘"
            foreground: panel.contentForeground
            bordered: true
            hasCursor: panel.cursorId === "theme"
            onClicked: panel.applyThemeColors()
            onHovered: function(on) { if (on) panel.cursor = panel.rowIndex("theme") }
          }

          Button {
            width: parent.width
            text: "Undo"
            foreground: panel.contentForeground
            bordered: true
            enabled: panel.canUndo
            opacity: panel.canUndo ? 1 : 0.4
            hasCursor: panel.cursorId === "undo"
            onClicked: panel.undo()
            onHovered: function(on) { if (on) panel.cursor = panel.rowIndex("undo") }
          }

          Text {
            width: parent.width
            visible: panel.followTheme
            text: "Picking a color turns theme-follow off."
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Qt.darker(panel.contentForeground, 1.4)
            font.family: panel.contentFontFamily
            font.pixelSize: Style.font.caption
          }

          PanelSeparator { foreground: panel.contentForeground }

          Column {
            id: glowSection
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "GLOW"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
            }

            Item {
              id: sliderOpacity
              width: parent.width
              height: opacityColumn.implicitHeight

              Rectangle {
                anchors.fill: parent
                radius: Style.cornerRadius
                color: panel.cursorId === "opacity" ? Color.menu.selectedBackground : "transparent"
              }

              Column {
                id: opacityColumn
                width: parent.width
                spacing: Style.space(4)

                RowLayout {
                  width: parent.width
                  Text {
                    text: "Opacity"
                    textFormat: Text.PlainText
                    color: panel.contentForeground
                    font.family: panel.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                    Layout.fillWidth: true
                  }
                  Text {
                    text: Math.round(panel.opacityValue * 100) + "%"
                    textFormat: Text.PlainText
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
                  onReleased: function(v) { panel.endUndoGesture() }
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(4)

              RowLayout {
                width: parent.width
                Text {
                  text: "Bloom"
                  textFormat: Text.PlainText
                  color: panel.contentForeground
                  font.family: panel.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  Layout.fillWidth: true
                }
                Text {
                  text: panel.bloomPx + " px"
                  textFormat: Text.PlainText
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
                onReleased: function(v) { panel.endUndoGesture() }
              }
            }

            ColorRow {
              id: glowRow
              width: parent.width
              value: panel.glowHex
              caption: panel.followTheme ? "Theme" : "Custom"
              hasCursor: panel.cursorId === "glow"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
              presets: ["#000000", "#1a1a1a", Settings.colorToHex(Color.background), Settings.colorToHex(Color.accent)]
              onPicked: function(hex) { panel.setGlowColor(hex) }
              onOpenRequested: panel.openPicker("glow")
              onHovered: panel.cursor = panel.rowIndex("glow")
            }
          }

          PanelSeparator { foreground: panel.contentForeground }

          Column {
            id: glyphSection
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "GLYPHS"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
            }

            QuietRow {
              width: parent.width
              label: "Force glyph color"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
              showSwitch: true
              checked: panel.forceGlyphs
              hasCursor: panel.cursorId === "force"
              onHovered: panel.cursor = panel.rowIndex("force")
              onTriggered: panel.setForceGlyphs(!panel.forceGlyphs)
            }

            ColorRow {
              id: glyphRow
              width: parent.width
              value: panel.displayGlyphHex
              caption: panel.autoContrast && panel.haveSample ? "Contrast" : (panel.followTheme ? "Theme" : "Custom")
              interactive: panel.forceGlyphs
              hasCursor: panel.cursorId === "glyph"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
              presets: ["#ffffff", "#d8d8d8", Settings.colorToHex(Color.foreground), Settings.colorToHex(Color.accent)]
              onPicked: function(hex) { panel.setGlyphColor(hex) }
              onOpenRequested: panel.openPicker("glyph")
              onHovered: panel.cursor = panel.rowIndex("glyph")
            }
          }

          PanelSeparator { foreground: panel.contentForeground }

          Column {
            id: presetSection
            width: parent.width
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "PRESETS"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
            }

            QuietRow {
              width: parent.width
              label: "Subtle wash"
              detail: "Theme · 40%"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
              hasCursor: panel.cursorId === "subtle"
              onHovered: panel.cursor = panel.rowIndex("subtle")
              onTriggered: panel.applyBuiltin("subtle")
            }
            QuietRow {
              width: parent.width
              label: "Strong contrast"
              detail: "Black · 92%"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
              hasCursor: panel.cursorId === "strong"
              onHovered: panel.cursor = panel.rowIndex("strong")
              onTriggered: panel.applyBuiltin("strong")
            }
            QuietRow {
              width: parent.width
              label: "Accent only"
              detail: "Accent · 72%"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
              hasCursor: panel.cursorId === "accent"
              onHovered: panel.cursor = panel.rowIndex("accent")
              onTriggered: panel.applyBuiltin("accent")
            }
            QuietRow {
              width: parent.width
              label: "Theme only"
              detail: "Keep sliders"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
              hasCursor: panel.cursorId === "themeOnly"
              onHovered: panel.cursor = panel.rowIndex("themeOnly")
              onTriggered: panel.applyBuiltin("theme")
            }

            Repeater {
              model: panel.live.customPresets
              QuietRow {
                required property var modelData
                required property int index
                width: presetSection.width
                label: modelData.name
                detail: modelData.followTheme ? "Theme" : String(modelData.color || "")
                foreground: panel.contentForeground
                fontFamily: panel.contentFontFamily
                hasCursor: panel.cursorId === ("custom:" + index)
                onHovered: panel.cursor = panel.rowIndex("custom:" + index)
                onTriggered: panel.applyCustom(index)
              }
            }

            QuietRow {
              width: parent.width
              visible: !panel.saving
              label: "Save current look"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
              hasCursor: panel.cursorId === "save"
              onHovered: panel.cursor = panel.rowIndex("save")
              onTriggered: panel.beginSave()
            }

            RowLayout {
              width: parent.width
              visible: panel.saving
              spacing: Style.space(8)

              Loader {
                id: saveLoader
                Layout.fillWidth: true
                Layout.preferredHeight: item ? item.implicitHeight : Style.space(28)
                active: panel.saving
                sourceComponent: PlainLine {
                  width: saveLoader.width
                  placeholderText: "Preset name"
                  maximumLength: 32
                  handleEscape: true
                  retainOnBlur: true
                  foreground: panel.contentForeground
                  fontFamily: panel.contentFontFamily
                  fontPixelSize: Style.font.bodySmall
                  onAccepted: function(value) { panel.commitSave(value) }
                  onRejected: panel.cancelSave()
                }
              }

              Button {
                text: "Save"
                foreground: panel.contentForeground
                bordered: true
                onClicked: panel.commitSave()
              }
            }
          }

          PanelSeparator { foreground: panel.contentForeground }

          Column {
            id: sampleSection
            width: parent.width
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "WALLPAPER"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
            }

            Button {
              width: parent.width
              text: panel.glowService && panel.glowService.sampleBusy ? "Sampling" : "Sample under bar"
              foreground: panel.contentForeground
              bordered: true
              hasCursor: panel.cursorId === "sample"
              enabled: !(panel.glowService && panel.glowService.sampleBusy)
              onClicked: panel.requestSample()
              onHovered: function(on) { if (on) panel.cursor = panel.rowIndex("sample") }
            }

            Item {
              width: parent.width
              height: followRow.implicitHeight

              QuietRow {
                id: followRow
                x: Style.space(14)
                width: parent.width - x
                label: "Follow wallpaper"
                foreground: panel.contentForeground
                fontFamily: panel.contentFontFamily
                showSwitch: true
                checked: panel.followWallpaper
                hasCursor: panel.cursorId === "follow"
                onHovered: panel.cursor = panel.rowIndex("follow")
                onTriggered: panel.setFollowWallpaper(!panel.followWallpaper)
              }
            }

            Text {
              width: parent.width
              visible: panel.glowService && panel.glowService.sampleNote !== ""
              text: panel.glowService ? panel.glowService.sampleNote : ""
              textFormat: Text.PlainText
              wrapMode: Text.WordWrap
              color: Qt.darker(panel.contentForeground, 1.4)
              font.family: panel.contentFontFamily
              font.pixelSize: Style.font.caption
            }

            PanelSeparator { foreground: panel.contentForeground }

            PanelSectionHeader {
              text: "READING"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
            }

            QuietRow {
              width: parent.width
              label: "Auto contrast"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
              showSwitch: true
              checked: panel.autoContrast
              hasCursor: panel.cursorId === "contrast"
              onHovered: panel.cursor = panel.rowIndex("contrast")
              onTriggered: panel.setAutoContrast(!panel.autoContrast)
            }
            QuietRow {
              width: parent.width
              label: "Warm with night light"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
              showSwitch: true
              checked: panel.nightLight
              hasCursor: panel.cursorId === "night"
              onHovered: panel.cursor = panel.rowIndex("night")
              onTriggered: panel.setNightLight(!panel.nightLight)
            }
            QuietRow {
              width: parent.width
              label: "Tint the bar icon"
              foreground: panel.contentForeground
              fontFamily: panel.contentFontFamily
              showSwitch: true
              checked: panel.tintChip
              hasCursor: panel.cursorId === "chip"
              onHovered: panel.cursor = panel.rowIndex("chip")
              onTriggered: panel.setTintChip(!panel.tintChip)
            }

            Text {
              width: parent.width
              text: "−/= opacity · ctrl+z undo · esc closes"
              textFormat: Text.PlainText
              color: Qt.darker(panel.contentForeground, 1.45)
              font.family: panel.contentFontFamily
              font.pixelSize: Style.font.caption
              topPadding: Style.space(6)
            }
          }
        }
      }

      Item {
        id: pickerLayer
        anchors.fill: parent
        visible: panel.pickerOpen
        z: 2
        onWidthChanged: if (panel.pickerOpen) panel.placePicker()
        onHeightChanged: if (panel.pickerOpen) panel.placePicker()

        MouseArea {
          anchors.fill: parent
          onClicked: panel.closePicker()
        }

        Rectangle {
          anchors.fill: parent
          color: Util.alpha(Color.popups.background, 0.72)
        }

        BorderSurface {
          id: pickerCard
          x: 0
          y: panel.pickerY
          width: parent.width
          height: pickerColumn.implicitHeight + Style.space(24)
          color: Color.popups.background
          radius: Style.cornerRadius
          borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(1)))
          clip: true

          MouseArea {
            anchors.fill: parent
            onPressed: function(mouse) { mouse.accepted = true }
          }

          Item {
            id: pickerFocus
            anchors.fill: parent
            focus: panel.pickerOpen
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                panel.closePicker()
                event.accepted = true
                return
              }
              if (picker.editing) return
              if (event.key === Qt.Key_Left && (event.modifiers & Qt.ShiftModifier)) picker.nudgeHue(-0.015)
              else if (event.key === Qt.Key_Right && (event.modifiers & Qt.ShiftModifier)) picker.nudgeHue(0.015)
              else if (event.key === Qt.Key_Left) picker.nudgeSv(-0.02, 0)
              else if (event.key === Qt.Key_Right) picker.nudgeSv(0.02, 0)
              else if (event.key === Qt.Key_Up) picker.nudgeSv(0, 0.02)
              else if (event.key === Qt.Key_Down) picker.nudgeSv(0, -0.02)
              else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) panel.closePicker()
              else return
              event.accepted = true
            }

            Column {
              id: pickerColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(12)
              spacing: Style.space(8)

              Text {
                width: parent.width
                text: panel.pickerTarget === "glyph" ? "Glyph color" : "Glow color"
                textFormat: Text.PlainText
                color: panel.contentForeground
                font.family: panel.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              Text {
                width: parent.width
                visible: panel.pickerTarget === "glow" && panel.nightLight && panel.glowService
                  && panel.glowService.sunsetKelvin > 0 && panel.glowService.sunsetKelvin < 6000
                text: "Night light warms this on the bar."
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                color: Qt.darker(panel.contentForeground, 1.4)
                font.family: panel.contentFontFamily
                font.pixelSize: Style.font.caption
              }

              ColorPicker {
                id: picker
                width: parent.width
                fieldHeight: Style.space(96)
                fieldLive: panel.pickerOpen
                value: panel.pickerTarget === "glyph" ? panel.glyphHex : panel.glowHex
                followTheme: panel.followTheme
                foreground: panel.contentForeground
                fontFamily: panel.contentFontFamily
                presets: panel.pickerTarget === "glyph"
                  ? ["#ffffff", "#f2f2f2", "#d8d8d8", "#a8a8a8", Settings.colorToHex(Color.foreground), Settings.colorToHex(Color.accent)]
                  : ["#000000", "#111111", "#1c1c1c", "#2b2b2b", Settings.colorToHex(Color.background), Settings.colorToHex(Color.accent)]
                onColorPicked: function(hex) {
                  if (panel.pickerTarget === "glyph") panel.setGlyphColor(hex)
                  else panel.setGlowColor(hex)
                }
              }

              Text {
                width: parent.width
                text: "Arrows move · shift left/right hue · esc back"
                textFormat: Text.PlainText
                color: Qt.darker(panel.contentForeground, 1.45)
                font.family: panel.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
      }
    }
  }
}
