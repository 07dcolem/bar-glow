import QtQuick
import qs.Commons
import qs.Ui
import "PlainEdit.js" as Edit

// Single-line editor that is not a TextInput or TextEdit.
// Qt 6.12 QQuickTextInput::q_canPasteChanged calls QMimeData::text() on
// every clipboard change for an editable field, before maximumLength runs.
// This item never subscribes to the clipboard. Paste is ignored.
FocusScope {
  id: root

  property string text: ""
  property string placeholderText: ""
  property int maximumLength: 64
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property int fontPixelSize: Style.font.bodySmall
  property bool handleEscape: false
  // Copy the typed value into `text` when focus leaves, so a button clicked
  // after the blur still reads it. Leave this off when `text` is bound.
  property bool retainOnBlur: false

  signal accepted(string value)
  signal editingFinished(string value)
  signal rejected()

  property string draft: ""
  property bool dirty: false
  property int cursor: 0
  property int anchor: 0
  readonly property string editText: dirty ? draft : text
  readonly property bool hasSelection: cursor !== anchor
  readonly property var borderSpec: Border.controlSpec(activeFocus ? "focus" : "normal", foreground, accent)
  readonly property real padL: Style.spacing.controlPaddingX + Border.left(borderSpec)
  readonly property real padR: Style.spacing.controlPaddingX + Border.right(borderSpec)
  readonly property real padT: Style.spacing.inputPaddingY + Border.top(borderSpec)
  readonly property real padB: Style.spacing.inputPaddingY + Border.bottom(borderSpec)

  implicitWidth: Style.space(120)
  implicitHeight: line.implicitHeight + padT + padB
  activeFocusOnTab: true

  onActiveFocusChanged: {
    if (activeFocus) {
      draft = text
      dirty = false
      cursor = editText.length
      anchor = cursor
      caretOn = true
      blink.restart()
    } else {
      blink.stop()
      if (dirty) finish(false)
    }
  }

  onTextChanged: {
    if (!dirty) {
      cursor = text.length
      anchor = cursor
    }
  }

  function finish(fromAccept) {
    var next = editText
    dirty = false
    draft = ""
    if (retainOnBlur) text = next
    if (fromAccept) accepted(next)
    editingFinished(next)
  }

  function apply(next) {
    dirty = true
    draft = next.text
    cursor = next.cursor
    anchor = next.anchor
    caretOn = true
    blink.restart()
  }

  // Prefix widths are rebuilt when the text changes. Bindings only read this
  // list. Measuring inside a binding writes TextMetrics and loops.
  property var advances: [0]

  function rebuildAdvances() {
    var src = editText
    var next = [0]
    var acc = ""
    for (var i = 0; i < src.length; i++) {
      acc += src.charAt(i)
      metrics.text = acc
      next.push(metrics.advanceWidth)
    }
    advances = next
  }

  onEditTextChanged: rebuildAdvances()
  onFontFamilyChanged: rebuildAdvances()
  onFontPixelSizeChanged: rebuildAdvances()
  Component.onCompleted: rebuildAdvances()

  function advance(index) {
    var list = advances
    if (!list || !list.length) return 0
    var i = index | 0
    if (i < 0) return 0
    if (i >= list.length) return list[list.length - 1]
    return list[i]
  }

  function indexAt(x) {
    var local = x - track.x
    var n = editText.length
    var best = 0
    var bestDist = Number.POSITIVE_INFINITY
    for (var i = 0; i <= n; i++) {
      var dist = Math.abs(advance(i) - local)
      if (dist < bestDist) {
        bestDist = dist
        best = i
      }
    }
    return best
  }

  function place(index, extend) {
    var n = Edit.clampIndex(editText, index)
    cursor = n
    if (!extend) anchor = n
  }

  Keys.onPressed: function(event) {
    if (!root.enabled) return
    if (event.key === Qt.Key_Escape) {
      if (root.handleEscape) {
        root.rejected()
        event.accepted = true
      }
      return
    }
    if (event.matches(StandardKey.Paste) || event.matches(StandardKey.Cut) || event.matches(StandardKey.Copy)) {
      event.accepted = true
      return
    }
    if (event.matches(StandardKey.SelectAll)) {
      root.anchor = 0
      root.cursor = root.editText.length
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.finish(true)
      event.accepted = true
      return
    }
    var extend = (event.modifiers & Qt.ShiftModifier) !== 0
    if (event.key === Qt.Key_Backspace) {
      root.apply(Edit.backspace(root.editText, root.cursor, root.anchor))
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Delete) {
      root.apply(Edit.deleteForward(root.editText, root.cursor, root.anchor))
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Left) {
      var left = Edit.move(root.editText, root.cursor, root.anchor, -1, extend)
      root.cursor = left.cursor
      root.anchor = left.anchor
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Right) {
      var right = Edit.move(root.editText, root.cursor, root.anchor, 1, extend)
      root.cursor = right.cursor
      root.anchor = right.anchor
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Home) {
      var toStart = Edit.home(root.editText, root.anchor, extend)
      root.cursor = toStart.cursor
      root.anchor = toStart.anchor
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_End) {
      var toEnd = Edit.end(root.editText, root.anchor, extend)
      root.cursor = toEnd.cursor
      root.anchor = toEnd.anchor
      event.accepted = true
      return
    }
    var mods = event.modifiers
    if ((mods & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0) return
    if (!event.text || !Edit.usable(event.text.charAt(0))) return
    root.apply(Edit.insert(root.editText, root.cursor, root.anchor, event.text, root.maximumLength))
    event.accepted = true
  }

  property bool caretOn: true
  Timer {
    id: blink
    interval: 530
    repeat: true
    running: false
    onTriggered: root.caretOn = !root.caretOn
  }

  BorderSurface {
    anchors.fill: parent
    color: Style.controlFill(root.activeFocus, false, root.foreground, root.accent)
    borderSpec: root.borderSpec
    radius: Style.cornerRadius
  }

  Item {
    id: view
    anchors.fill: parent
    anchors.leftMargin: root.padL
    anchors.rightMargin: root.padR
    anchors.topMargin: root.padT
    anchors.bottomMargin: root.padB
    clip: true

    Item {
      id: track
      height: line.implicitHeight
      width: Math.max(line.implicitWidth, 1)
      y: Math.max(0, (view.height - height) / 2)
      x: {
        var caret = root.advance(root.cursor)
        var overflow = caret + 2 - view.width
        return overflow > 0 ? -overflow : 0
      }

      Rectangle {
        visible: root.hasSelection
        x: root.advance(Math.min(root.cursor, root.anchor))
        width: Math.max(1, root.advance(Math.max(root.cursor, root.anchor)) - x)
        height: parent.height
        color: Style.selectionFillFor(root.foreground, root.accent)
      }

      Text {
        id: line
        text: root.editText === "" ? root.placeholderText : root.editText
        textFormat: Text.PlainText
        color: root.editText === "" ? Qt.darker(root.foreground, 1.6) : root.foreground
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
      }

      Rectangle {
        visible: root.activeFocus && !root.hasSelection && root.caretOn
        x: root.advance(root.cursor)
        y: 0
        width: 1
        height: parent.height
        color: root.foreground
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.IBeamCursor
      enabled: root.enabled
      onPressed: function(mouse) {
        root.forceActiveFocus()
        root.place(root.indexAt(mouse.x), false)
        mouse.accepted = true
      }
    }
  }

  TextMetrics {
    id: metrics
    font.family: line.font.family
    font.pixelSize: line.font.pixelSize
  }
}
