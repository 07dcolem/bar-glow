import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Settings.js" as Settings

Column {
  id: root

  property string label: ""
  property string value: "#000000"
  property var presets: ["#000000", "#141414", "#2a2a2a", "#4a4a4a", "#888888", "#ffffff"]
  property color foreground: Color.popups.text
  property bool interactive: true
  property bool followTheme: false

  signal colorPicked(string hex)
  readonly property bool editing: hexField.activeFocus

  spacing: Style.space(8)
  width: parent ? parent.width : implicitWidth
  opacity: interactive ? 1 : 0.45
  enabled: interactive

  readonly property var hsv: Settings.hexToHsv(root.value)
  property bool sliding: false

  function emitHex(hex) {
    var next = Settings.normalizeHex(hex)
    if (!next || next.charAt(0) !== "#") return
    if (next === Settings.normalizeHex(root.value) && !root.followTheme) return
    root.colorPicked(next)
  }

  function emitHsv(h, s, v) {
    emitHex(Settings.hsvToHex(h, s, v))
  }

  Text {
    visible: root.label !== ""
    text: root.label
    color: Qt.darker(root.foreground, 1.4)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.bold: true
  }

  Row {
    spacing: Style.space(6)
    Repeater {
      model: root.presets
      Rectangle {
        required property string modelData
        width: Style.space(18)
        height: Style.space(18)
        radius: Math.min(Style.cornerRadius, width / 4)
        color: modelData
        border.width: Settings.normalizeHex(modelData) === Settings.normalizeHex(root.value) ? 2 : 1
        border.color: Settings.normalizeHex(modelData) === Settings.normalizeHex(root.value)
          ? Color.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)

        MouseArea {
          anchors.fill: parent
          enabled: root.interactive
          cursorShape: Qt.PointingHandCursor
          onClicked: root.emitHex(modelData)
        }
      }
    }
  }

  RowLayout {
    width: parent.width
    spacing: Style.space(10)

    Rectangle {
      Layout.preferredWidth: Style.space(36)
      Layout.preferredHeight: Style.space(28)
      radius: Style.cornerRadius
      color: root.value
      border.width: 1
      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
    }

    TextField {
      id: hexField
      Layout.fillWidth: true
      foreground: root.foreground
      text: root.value
      enabled: root.interactive
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      onEditingFinished: root.emitHex(text)
      onAccepted: root.emitHex(text)
    }
  }

  Column {
    width: parent.width
    spacing: Style.space(4)

    RowLayout {
      width: parent.width
      Text {
        text: "H"
        color: Qt.darker(root.foreground, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        Layout.preferredWidth: Style.space(14)
      }
      PanelSlider {
        Layout.fillWidth: true
        minimum: 0
        maximum: 1
        step: 0.01
        value: root.hsv.h
        fillColor: root.foreground
        knobColor: root.foreground
        trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
        enabled: root.interactive
        onMoved: function(v) { root.sliding = true; root.emitHsv(v, root.hsv.s, root.hsv.v) }
        onReleased: function() { root.sliding = false }
      }
    }

    RowLayout {
      width: parent.width
      Text {
        text: "S"
        color: Qt.darker(root.foreground, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        Layout.preferredWidth: Style.space(14)
      }
      PanelSlider {
        Layout.fillWidth: true
        minimum: 0
        maximum: 1
        step: 0.01
        value: root.hsv.s
        fillColor: root.foreground
        knobColor: root.foreground
        trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
        enabled: root.interactive
        onMoved: function(v) { root.sliding = true; root.emitHsv(root.hsv.h, v, root.hsv.v) }
        onReleased: function() { root.sliding = false }
      }
    }

    RowLayout {
      width: parent.width
      Text {
        text: "V"
        color: Qt.darker(root.foreground, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        Layout.preferredWidth: Style.space(14)
      }
      PanelSlider {
        Layout.fillWidth: true
        minimum: 0
        maximum: 1
        step: 0.01
        value: root.hsv.v
        fillColor: root.foreground
        knobColor: root.foreground
        trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
        enabled: root.interactive
        onMoved: function(v) { root.sliding = true; root.emitHsv(root.hsv.h, root.hsv.s, v) }
        onReleased: function() { root.sliding = false }
      }
    }
  }
}
