import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The bar glyph. It is faint while every server is Connecting or none is
// configured. A dot on its top inline-end corner shows while a server needs
// attention.
BarIconButton {
  id: root

  property bool attention: false
  property bool waiting: false

  text: "󰒋"
  foreground: bar
    ? (waiting ? Util.alpha(bar.barForeground, 0.45) : bar.barForeground)
    : Commons.Color.foreground

  // The dot has a ring in the bar background, so it reads on top of the glyph.
  Rectangle {
    readonly property real ring: root.bar && !root.bar.transparent ? Style.spacing.xxs : 0
    readonly property real glyphLeft: root.width / 2 - root.glyphPaintedWidth / 2
    readonly property real glyphRight: root.width / 2 + root.glyphPaintedWidth / 2
    readonly property real glyphTop: root.height / 2 - root.glyphPaintedHeight / 2

    visible: root.attention
    width: Style.spacing.md + ring * 2
    height: width
    radius: width / 2
    color: root.bar ? root.bar.urgent : Commons.Color.urgent
    border.width: ring
    border.color: root.bar ? root.bar.background : "transparent"
    x: LayoutMirroring.enabled
      ? glyphLeft - Style.spacing.xxs - ring
      : glyphRight + Style.spacing.xxs + ring - width
    y: glyphTop - Style.spacing.xxs - ring
  }
}
