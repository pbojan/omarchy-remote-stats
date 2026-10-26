import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../common"

// One line of the add-server test: a status glyph, the check text, and an
// optional detail and fix hint under it.
RowLayout {
  id: root

  required property Theme theme
  // ok, fail, run or skip
  property string status: "skip"
  property string text: ""
  property string detail: ""
  property string hint: ""

  readonly property color textColor: status === "fail" ? theme.urgent
    : (status === "run" ? theme.dim
    : (status === "skip" ? theme.faint : theme.foreground))

  spacing: Style.spacing.md

  PlainText {
    Layout.alignment: Qt.AlignTop
    text: root.status === "ok" ? "󰄬" : (root.status === "fail" ? "󰅖" : "󰇘")
    color: root.textColor
    font.family: root.theme.fontFamily
    font.pixelSize: Style.font.iconSmall
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 0

    PlainText {
      Layout.fillWidth: true
      text: root.text
      color: root.textColor
      font.family: root.theme.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.Wrap
    }

    PlainText {
      Layout.fillWidth: true
      visible: root.detail !== ""
      text: root.detail
      color: root.status === "fail" ? root.theme.urgent : root.theme.dim
      font.family: root.theme.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WrapAnywhere
    }

    PlainText {
      Layout.fillWidth: true
      visible: root.hint !== ""
      text: root.hint
      color: root.theme.dim
      font.family: root.theme.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
    }
  }
}
