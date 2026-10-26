import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../common"

// Label and value on one line, then an optional meter and caption.
ColumnLayout {
  id: root

  required property Theme theme
  property string label: ""
  property string value: ""
  property string caption: ""
  // With `meter`, a percent of 0–100 draws the fill; a negative percent
  // draws the empty track.
  property bool meter: false
  property real percent: -1
  property bool critical: false
  property bool faintValue: false

  spacing: Style.spacing.labelGap

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.lg

    PlainText {
      Layout.fillWidth: true
      text: root.label
      color: root.theme.foreground
      font.family: root.theme.fontFamily
      wrapMode: Text.Wrap
    }

    PlainText {
      Layout.alignment: Qt.AlignBaseline
      text: root.value
      color: root.critical ? root.theme.urgent : (root.faintValue ? root.theme.faint : root.theme.foreground)
      font.family: root.theme.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.features: { "tnum": 1 }
    }
  }

  Meter {
    Layout.fillWidth: true
    visible: root.meter
    value: root.percent >= 0 ? root.percent / 100 : -1
    foreground: root.theme.foreground
    fillColor: root.critical ? root.theme.urgent : root.theme.foreground
  }

  PlainText {
    Layout.fillWidth: true
    visible: root.caption !== ""
    text: root.caption
    color: root.theme.dim
    font.family: root.theme.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.Wrap
  }
}
