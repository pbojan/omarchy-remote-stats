import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../common"

// Shown in place of the server list while no server is configured.
ColumnLayout {
  id: root

  required property Theme theme
  required property var strings
  property int interval: 30

  spacing: Style.spacing.sm

  Item { implicitHeight: Style.spacing.huge - Style.spacing.sm }

  PlainText {
    Layout.alignment: Qt.AlignHCenter
    text: "󰒋"
    color: root.theme.faint
    font.family: root.theme.fontFamily
    font.pixelSize: Math.round(Style.font.iconLarge * 1.5)
  }

  PlainText {
    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: Style.spacing.sm
    text: root.strings.t("emptyTitle")
    color: root.theme.foreground
    font.family: root.theme.fontFamily
    font.weight: Font.DemiBold
  }

  PlainText {
    Layout.alignment: Qt.AlignHCenter
    Layout.maximumWidth: Style.space(280)
    text: root.strings.t("emptyText").arg(Commons.I18n.formatNumber(root.interval))
    color: root.theme.dim
    font.family: root.theme.fontFamily
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.Wrap
  }

  Item { implicitHeight: Style.spacing.huge - Style.spacing.sm }
}
