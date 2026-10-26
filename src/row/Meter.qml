import QtQuick
import qs.Commons

// Pill meter, the same shape as the Agents panel meters. `value` is 0–1; a
// negative value draws the track only. The fill anchors to the left edge,
// which LayoutMirroring flips in RTL.
Item {
  id: root

  property real value: -1
  property color foreground: "white"
  property color track: Util.alpha(foreground, 0.18)
  property color fillColor: foreground

  // The glide is on the value, not on the width: a new value moves the fill
  // smoothly, but a size change from the layout (a new or opened row)
  // applies at once instead of filling in from 0.
  property real fraction: Math.max(0, Math.min(1, value))
  Behavior on fraction {
    NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic }
  }

  implicitHeight: Style.spacing.sm

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: root.track
  }

  Rectangle {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    visible: root.value >= 0
    height: parent.height
    radius: height / 2
    width: parent.width * root.fraction
    color: root.fillColor
  }
}
