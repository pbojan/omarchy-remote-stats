import QtQuick
import qs.Commons
import qs.Commons as Commons

// The panel's colours and font. They follow the bar, as in Omarchy's own
// panels. Every Remote Stats component takes this one `theme` instead of a
// foreground, an urgent colour and a font each.
QtObject {
  id: root

  property QtObject bar: null

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  // Captions, hints and other secondary text.
  readonly property color dim: Util.alpha(root.foreground, 0.7)
  // Placeholders and values that are not there yet.
  readonly property color faint: Util.alpha(root.foreground, 0.45)
  readonly property color hoverFill: Style.hoverFillFor(root.foreground, Commons.Color.accent)
}
