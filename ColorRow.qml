pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import "Settings.js" as Settings

// Compact color row: live swatch, hex, and a few preset chips.
// The swatch and the label open the full picker. A preset chip applies itself.
Item {
  id: root

  property string value: "#000000"
  property string caption: ""
  property var presets: []
  property bool interactive: true
  property bool hasCursor: false
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  signal picked(string hex)
  signal openRequested()
  signal hovered()

  implicitHeight: Style.space(36)
  implicitWidth: Style.space(240)
  opacity: interactive ? 1 : 0.45

  readonly property var shownPresets: {
    var src = root.presets || []
    var out = []
    var seen = {}
    for (var i = 0; i < src.length && out.length < 4; i++) {
      var hex = Settings.normalizeHex(src[i])
      if (!hex || hex.charAt(0) !== "#" || seen[hex]) continue
      seen[hex] = true
      out.push(hex)
    }
    return out
  }

  function cycle(direction) {
    var list = root.shownPresets
    if (!list.length || !root.interactive) return
    var current = Settings.normalizeHex(root.value)
    var index = -1
    for (var i = 0; i < list.length; i++) {
      if (list[i] === current) index = i
    }
    var nextIndex = index < 0
      ? (direction < 0 ? list.length - 1 : 0)
      : (index + (direction < 0 ? -1 : 1) + list.length) % list.length
    root.picked(list[nextIndex])
  }

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: root.hasCursor ? Color.menu.selectedBackground : "transparent"
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.interactive
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onContainsMouseChanged: if (containsMouse) root.hovered()
    onClicked: root.openRequested()

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(4)
      anchors.rightMargin: Style.space(4)
      spacing: Style.space(8)

      Rectangle {
        Layout.preferredWidth: Style.space(16)
        Layout.preferredHeight: Style.space(16)
        radius: Style.cornerRadius > 0 ? Style.space(2) : 0
        color: root.value
        border.width: 1
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
      }

      ColumnLayout {
        spacing: 0
        Layout.fillWidth: true

        Text {
          text: Settings.normalizeHex(root.value) || root.value
          textFormat: Text.PlainText
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          visible: root.caption !== ""
          text: root.caption
          textFormat: Text.PlainText
          color: Qt.darker(root.foreground, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }

      Row {
        spacing: Style.space(4)
        Layout.alignment: Qt.AlignVCenter

        Repeater {
          model: root.shownPresets

          Rectangle {
            id: chip
            required property string modelData
            required property int index
            width: Style.space(14)
            height: Style.space(14)
            radius: Style.cornerRadius > 0 ? Style.space(2) : 0
            color: modelData
            border.width: Settings.normalizeHex(modelData) === Settings.normalizeHex(root.value) ? 2 : 1
            border.color: Settings.normalizeHex(modelData) === Settings.normalizeHex(root.value)
              ? Color.accent
              : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)

            MouseArea {
              anchors.fill: parent
              enabled: root.interactive
              cursorShape: Qt.PointingHandCursor
              onClicked: root.picked(chip.modelData)
            }
          }
        }
      }
    }
  }
}
