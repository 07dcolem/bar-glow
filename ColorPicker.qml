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
  property string fontFamily: Style.font.family
  property bool interactive: true
  property bool followTheme: false

  signal colorPicked(string hex)
  readonly property bool editing: hexField.activeFocus

  spacing: Style.space(8)
  width: parent ? parent.width : implicitWidth
  opacity: interactive ? 1 : 0.45
  enabled: interactive

  readonly property var hsv: Settings.hexToHsv(root.value)
  readonly property int knob: Style.space(14)

  function emitHex(hex) {
    var next = Settings.normalizeHex(hex)
    if (!next || next.charAt(0) !== "#") return
    if (next === Settings.normalizeHex(root.value) && !root.followTheme) return
    root.colorPicked(next)
  }

  function emitHsv(h, s, v) {
    emitHex(Settings.hsvToHex(h, s, v))
  }

  function clamp01(n) {
    return Math.max(0, Math.min(1, n))
  }

  Text {
    visible: root.label !== ""
    text: root.label
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.bold: true
  }

  // Saturation across, value down. White-to-hue under a transparent-to-black veil.
  Item {
    id: field
    width: parent.width
    height: Style.space(128)

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      clip: true
      color: "white"

      Rectangle {
        anchors.fill: parent
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: "white" }
          GradientStop { position: 1.0; color: Qt.hsva(root.hsv.h, 1, 1, 1) }
        }
      }

      Rectangle {
        anchors.fill: parent
        gradient: Gradient {
          GradientStop { position: 0.0; color: "transparent" }
          GradientStop { position: 1.0; color: "black" }
        }
      }
    }

    Rectangle {
      width: root.knob
      height: root.knob
      radius: width / 2
      x: root.hsv.s * (field.width - width)
      y: (1 - root.hsv.v) * (field.height - height)
      color: "transparent"
      border.width: 2
      border.color: root.hsv.v > 0.55 ? "#111111" : "#ffffff"
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.interactive
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onPressed: function(mouse) { root.emitHsv(root.hsv.h, root.clamp01(mouse.x / width), root.clamp01(1 - mouse.y / height)) }
      onPositionChanged: function(mouse) {
        if (!pressed) return
        root.emitHsv(root.hsv.h, root.clamp01(mouse.x / width), root.clamp01(1 - mouse.y / height))
      }
    }
  }

  // Hue.
  Item {
    id: hueBar
    width: parent.width
    height: Style.space(16)

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.00; color: "#ff0000" }
        GradientStop { position: 0.17; color: "#ffff00" }
        GradientStop { position: 0.33; color: "#00ff00" }
        GradientStop { position: 0.50; color: "#00ffff" }
        GradientStop { position: 0.67; color: "#0000ff" }
        GradientStop { position: 0.83; color: "#ff00ff" }
        GradientStop { position: 1.00; color: "#ff0000" }
      }
    }

    Rectangle {
      width: root.knob
      height: parent.height + Style.space(4)
      radius: Style.cornerRadius > 0 ? width / 2 : 0
      y: -Style.space(2)
      x: root.hsv.h * (hueBar.width - width)
      color: "transparent"
      border.width: 2
      border.color: "#ffffff"
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.interactive
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onPressed: function(mouse) { root.emitHsv(root.clamp01(mouse.x / width), root.hsv.s, root.hsv.v) }
      onPositionChanged: function(mouse) {
        if (!pressed) return
        root.emitHsv(root.clamp01(mouse.x / width), root.hsv.s, root.hsv.v)
      }
    }
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
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      onEditingFinished: root.emitHex(text)
      onAccepted: root.emitHex(text)
    }
  }
}
