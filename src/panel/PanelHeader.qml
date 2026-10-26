import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../common"

// The top of the panel, which stays in place while the list scrolls: the
// title, then for the list the Refresh and Add server buttons and the list
// header, or for the form a close button.
ColumnLayout {
  id: root

  required property Theme theme
  required property var strings
  // "list" or "add", as in PanelContent.
  property string view: "list"
  property int serverCount: 0
  // A problem with config.json, in both views; empty when there is none.
  property string notice: ""

  signal refreshRequested()
  signal addRequested()
  signal formCloseRequested()

  spacing: Style.spacing.panelGap

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.md

    PanelHero {
      Layout.fillWidth: true
      title: root.strings.t("title")
      foreground: root.theme.foreground
      fontFamily: root.theme.fontFamily
      iconSize: Style.font.iconLarge
      iconComponent: Component {
        PlainText {
          text: "󰒋"
          color: root.theme.foreground
          font.family: root.theme.fontFamily
          font.pixelSize: Style.font.iconLarge
        }
      }
    }

    PanelActionButton {
      visible: root.view === "add"
      iconText: "󰅖"
      tooltipText: root.strings.t("form.close")
      foreground: root.theme.dim
      hoverColor: root.theme.foreground
      fontFamily: root.theme.fontFamily
      fontSize: Style.font.iconSmall
      size: Style.spacing.controlHeight
      onClicked: root.formCloseRequested()
    }
  }

  RowLayout {
    visible: root.view === "list"
    Layout.fillWidth: true
    spacing: Style.spacing.md

    ActionButton {
      text: root.strings.t("refresh")
      iconText: "󰑐"
      enabled: root.serverCount > 0
      opacity: enabled ? 1 : 0.5
      onClicked: root.refreshRequested()
    }

    // Filled while the list is empty: the one thing to do next.
    ActionButton {
      text: root.strings.t("addServer")
      iconText: "󰐕"
      background: root.serverCount === 0 ? root.theme.hoverFill : "transparent"
      onClicked: root.addRequested()
    }
  }

  PlainText {
    visible: root.notice !== ""
    Layout.fillWidth: true
    text: root.notice
    color: root.theme.urgent
    font.family: root.theme.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.Wrap
  }

  PanelSeparator {
    visible: root.view === "list"
    Layout.fillWidth: true
    foreground: root.theme.foreground
  }

  RowLayout {
    visible: root.view === "list" && root.serverCount > 0
    Layout.fillWidth: true
    spacing: Style.spacing.lg

    PanelSectionHeader {
      Layout.fillWidth: true
      text: root.strings.t("servers")
      foreground: root.theme.foreground
      fontFamily: root.theme.fontFamily
    }

    PanelSectionHeader {
      text: Commons.I18n.formatNumber(root.serverCount)
      foreground: root.theme.foreground
      fontFamily: root.theme.fontFamily
    }
  }

  // The two list actions share the row equally.
  component ActionButton: Button {
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    iconSize: Style.font.iconSmall
    fontSize: Style.font.bodySmall
    foreground: root.theme.foreground
    fontFamily: root.theme.fontFamily
    bordered: true
  }
}
