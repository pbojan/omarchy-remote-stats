import QtQuick
import qs.Commons
import "../common"
import "../logic/Status.js" as Status

// Status label at the end of a server row. Each status maps to one look
// from the design spec; all colours are theme roles with an opacity.
Rectangle {
  id: root

  required property Theme theme
  property string status: "connecting"
  property string text: ""

  readonly property bool urgentStatus: Status.needsAttention(status)
  readonly property bool outlined: status === "connecting" || status === "issue"

  implicitWidth: label.implicitWidth + Style.spacing.md * 2
  implicitHeight: Math.round(Style.font.caption * 1.7)
  radius: Style.cornerRadius
  opacity: status === "stale" ? 0.5 : 1
  color: outlined ? "transparent" : (urgentStatus ? Util.alpha(theme.urgent, 0.15) : Util.alpha(theme.foreground, 0.1))
  border.width: outlined ? 1 : 0
  border.color: status === "issue" ? Util.alpha(theme.urgent, 0.5) : Util.alpha(theme.foreground, 0.22)

  PlainText {
    id: label
    anchors.centerIn: parent
    text: root.text
    color: root.urgentStatus ? root.theme.urgent : (root.status === "connecting" ? root.theme.dim : root.theme.foreground)
    font.family: root.theme.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.capitalization: Font.AllUppercase
    font.letterSpacing: Style.font.caption * 0.06
  }
}
