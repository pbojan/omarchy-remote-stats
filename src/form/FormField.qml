import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../common"

// One form input: Omarchy's TextField at control height, with a help line
// under it. An error replaces the help line and turns the border urgent.
ColumnLayout {
  id: root

  required property Theme theme
  property alias text: field.text
  property alias placeholderText: field.placeholderText
  property alias input: field
  property string help: ""
  property string error: ""
  // Targets and key paths read left to right in every language.
  property bool ltr: false

  signal accepted()
  signal escapePressed()

  spacing: Style.spacing.labelGap

  TextField {
    id: field
    Layout.fillWidth: true
    Layout.preferredHeight: Style.spacing.controlHeight
    LayoutMirroring.enabled: root.ltr ? false : root.LayoutMirroring.enabled
    foreground: root.theme.foreground
    font.family: root.theme.fontFamily
    font.pixelSize: Style.font.bodySmall
    horizontalPadding: Style.spacing.lg
    verticalPadding: 0
    verticalAlignment: TextInput.AlignVCenter
    placeholderTextColor: root.theme.faint
    selectByMouse: true
    onAccepted: root.accepted()
    Keys.onEscapePressed: root.escapePressed()

    background: BorderSurface {
      color: Style.controlFill(field._focused, field._hot, field.foreground, field.accent)
      borderSpec: root.error !== ""
        ? Border.flat(root.theme.urgent, Math.max(1, Border.top(field._borderSpec)))
        : field._borderSpec
      radius: Style.cornerRadius
    }
  }

  PlainText {
    Layout.fillWidth: true
    visible: text !== ""
    text: root.error !== "" ? root.error : root.help
    color: root.error !== "" ? root.theme.urgent : root.theme.dim
    font.family: root.theme.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WrapAnywhere
  }
}
