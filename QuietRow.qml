import QtQuick
import qs.Commons
import qs.Ui

// One settings row: label, optional detail, optional switch. No card chrome.
Item {
  id: row

  property string label: ""
  property string detail: ""
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family
  property bool hasCursor: false
  property bool showSwitch: false
  property bool checked: false

  signal triggered()
  signal hovered()

  implicitHeight: Style.space(34)
  implicitWidth: Style.space(200)

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: row.hasCursor ? Color.menu.selectedBackground : "transparent"
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onContainsMouseChanged: if (containsMouse) row.hovered()
    onClicked: row.triggered()
  }

  Text {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(8)
    anchors.right: row.showSwitch ? switchItem.left : detailText.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    text: row.label
    textFormat: Text.PlainText
    color: row.foreground
    font.family: row.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  Text {
    id: detailText
    visible: !row.showSwitch && row.detail !== ""
    anchors.right: parent.right
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    text: row.detail
    textFormat: Text.PlainText
    color: Qt.darker(row.foreground, 1.4)
    font.family: row.fontFamily
    font.pixelSize: Style.font.caption
  }

  ToggleSwitch {
    id: switchItem
    visible: row.showSwitch
    checked: row.checked
    interactive: false
    hasCursor: row.hasCursor
    foreground: row.foreground
    anchors.right: parent.right
    anchors.rightMargin: Style.space(4)
    anchors.verticalCenter: parent.verticalCenter
  }
}
