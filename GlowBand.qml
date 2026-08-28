import QtQuick
import qs.Commons

// Full-width black wash behind the bar, plus a short bloom on the inner edge.
// The parent window already spans the bar plus the bloom.
Item {
  id: root

  property string edge: "top"
  property int barSpan: 26
  property int glowSize: 18
  property color base: Qt.rgba(0, 0, 0, 1)
  property real peak: 0.7

  readonly property bool horizontal: edge === "left" || edge === "right"
  readonly property bool fromEnd: edge === "bottom" || edge === "right"
  readonly property color wash: Util.alpha(base, peak)

  function bloomColor(t) {
    return Util.alpha(root.base, root.peak * Math.exp(-3.2 * t))
  }

  // Solid wash across the whole bar so every glyph sits on the same black.
  Rectangle {
    color: root.wash
    x: root.edge === "right" ? parent.width - root.barSpan : 0
    y: root.edge === "bottom" ? parent.height - root.barSpan : 0
    width: root.horizontal ? root.barSpan : parent.width
    height: root.horizontal ? parent.height : root.barSpan
  }

  Rectangle {
    visible: root.glowSize > 0
    x: root.edge === "left" ? root.barSpan
      : (root.edge === "right" ? parent.width - root.barSpan - root.glowSize : 0)
    y: root.edge === "top" ? root.barSpan
      : (root.edge === "bottom" ? parent.height - root.barSpan - root.glowSize : 0)
    width: root.horizontal ? root.glowSize : parent.width
    height: root.horizontal ? parent.height : root.glowSize

    gradient: Gradient {
      orientation: root.horizontal ? Gradient.Horizontal : Gradient.Vertical
      GradientStop { position: 0.00; color: root.bloomColor(root.fromEnd ? 1.00 : 0.00) }
      GradientStop { position: 0.22; color: root.bloomColor(root.fromEnd ? 0.78 : 0.22) }
      GradientStop { position: 0.50; color: root.bloomColor(root.fromEnd ? 0.50 : 0.50) }
      GradientStop { position: 0.78; color: root.bloomColor(root.fromEnd ? 0.22 : 0.78) }
      GradientStop { position: 1.00; color: root.bloomColor(root.fromEnd ? 0.00 : 1.00) }
    }
  }
}
