import QtQuick

// Faint background tint. No logo and no center shape. The glow color and the
// glyph color cover the panel evenly and only fade at the edges. A change
// brightens that tint for a moment.
Item {
  id: root

  property color halo: "#000000"
  property color core: "#ffffff"
  property bool running: false
  property real reveal: 0
  property real breath: 0
  property real boost: 0
  property real ripple: 0
  property bool rippling: false

  anchors.fill: parent

  function start() {
    reveal = 0
    running = true
    revealAnim.restart()
    haloWash.requestPaint()
    coreWash.requestPaint()
  }

  function stop() {
    running = false
    reveal = 0
    boost = 0
    rippling = false
  }

  function bump() {
    boost = 1
    boostAnim.restart()
  }

  function pulse() {
    boost = 1
    ripple = 0
    rippling = true
    boostAnim.restart()
    rippleAnim.restart()
  }

  function cssColor(color, alpha) {
    return "rgba("
      + Math.round(color.r * 255) + ","
      + Math.round(color.g * 255) + ","
      + Math.round(color.b * 255) + ","
      + alpha + ")"
  }

  // Even field, faded only near the panel edges. No circle, logo, or corner.
  function paintField(ctx, width, height, color, peak) {
    ctx.save()
    ctx.globalCompositeOperation = "source-over"
    ctx.fillStyle = root.cssColor(color, peak)
    ctx.fillRect(0, 0, width, height)
    ctx.globalCompositeOperation = "destination-in"
    var vertical = ctx.createLinearGradient(0, 0, 0, height)
    vertical.addColorStop(0.0, "rgba(0,0,0,0)")
    vertical.addColorStop(0.14, "rgba(0,0,0,0.12)")
    vertical.addColorStop(0.32, "rgba(0,0,0,0.55)")
    vertical.addColorStop(0.46, "rgba(0,0,0,1)")
    vertical.addColorStop(0.54, "rgba(0,0,0,1)")
    vertical.addColorStop(0.68, "rgba(0,0,0,0.55)")
    vertical.addColorStop(0.86, "rgba(0,0,0,0.12)")
    vertical.addColorStop(1.0, "rgba(0,0,0,0)")
    ctx.fillStyle = vertical
    ctx.fillRect(0, 0, width, height)
    var horizontal = ctx.createLinearGradient(0, 0, width, 0)
    horizontal.addColorStop(0.0, "rgba(0,0,0,0)")
    horizontal.addColorStop(0.1, "rgba(0,0,0,0.12)")
    horizontal.addColorStop(0.26, "rgba(0,0,0,0.55)")
    horizontal.addColorStop(0.4, "rgba(0,0,0,1)")
    horizontal.addColorStop(0.6, "rgba(0,0,0,1)")
    horizontal.addColorStop(0.74, "rgba(0,0,0,0.55)")
    horizontal.addColorStop(0.9, "rgba(0,0,0,0.12)")
    horizontal.addColorStop(1.0, "rgba(0,0,0,0)")
    ctx.fillStyle = horizontal
    ctx.fillRect(0, 0, width, height)
    ctx.restore()
  }

  NumberAnimation {
    id: revealAnim
    target: root
    property: "reveal"
    to: 1
    duration: 400
    easing.type: Easing.OutCubic
  }

  SequentialAnimation on breath {
    running: root.running
    loops: Animation.Infinite
    NumberAnimation { from: 0; to: 1; duration: 2600; easing.type: Easing.InOutSine }
    NumberAnimation { from: 1; to: 0; duration: 2600; easing.type: Easing.InOutSine }
  }

  NumberAnimation {
    id: boostAnim
    target: root
    property: "boost"
    to: 0
    duration: 520
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: rippleAnim
    target: root
    property: "ripple"
    from: 0
    to: 1
    duration: 520
    easing.type: Easing.OutCubic
    onFinished: root.rippling = false
  }

  onHaloChanged: haloWash.requestPaint()
  onCoreChanged: coreWash.requestPaint()

  Canvas {
    id: haloWash
    anchors.fill: parent
    opacity: root.reveal * (0.22 + 0.03 * root.breath + 0.16 * root.boost)

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (width < 8 || height < 8) return
      root.paintField(ctx, width, height, root.halo, 0.55)
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
  }

  Canvas {
    id: coreWash
    anchors.fill: parent
    opacity: root.reveal * (0.18 + 0.03 * (1 - root.breath) + 0.14 * root.boost)

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (width < 8 || height < 8) return
      root.paintField(ctx, width, height, root.core, 0.4)
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
  }
}
