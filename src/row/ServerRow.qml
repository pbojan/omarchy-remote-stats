import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../common"

// One server in the panel list: a header that opens and closes the row, an
// inline remove confirm, and the open part (ServerDetails). The row holds no
// state: the panel passes it in and handles the signals.
Rectangle {
  id: row

  required property Theme theme
  required property var strings
  property var server: ({})
  property bool confirming: false
  property bool hasCursor: false
  property bool showDisks: true

  signal toggleRequested()
  signal removeRequested()
  signal removeConfirmed()
  signal removeCancelled()
  signal hovered()

  readonly property string name: server.name || ""
  readonly property bool open: !!server.open

  implicitHeight: column.implicitHeight
  radius: Style.cornerRadius
  color: open ? theme.hoverFill : "transparent"

  ColumnLayout {
    id: column
    width: parent.width
    spacing: 0

    CursorSurface {
      visible: !row.confirming
      Layout.fillWidth: true
      implicitHeight: Math.max(Style.spacing.popupRowHeight, headerRow.implicitHeight)
      hasCursor: row.hasCursor && !row.open
      foreground: row.theme.foreground
      fill: row.theme.hoverFill

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (containsMouse) row.hovered()
        onClicked: row.toggleRequested()
      }

      RowLayout {
        id: headerRow
        anchors.fill: parent
        anchors.leftMargin: Style.spacing.rowPaddingX
        spacing: Style.spacing.md

        PlainText {
          text: row.open ? "󰅀" : (LayoutMirroring.enabled ? "󰅁" : "󰅂")
          color: row.theme.dim
          font.family: row.theme.fontFamily
          font.pixelSize: Style.font.iconSmall
        }

        PlainText {
          Layout.fillWidth: true
          text: row.name
          color: row.theme.foreground
          font.family: row.theme.fontFamily
          wrapMode: Text.WrapAnywhere
        }

        StatusChip {
          theme: row.theme
          status: row.server.status || "connecting"
          text: row.strings.t("status." + status)
        }

        PanelActionButton {
          iconText: "󰛌"
          tooltipText: row.strings.t("removeLabel").arg(row.name)
          foreground: row.theme.dim
          hoverColor: row.theme.urgent
          fontFamily: row.theme.fontFamily
          fontSize: Style.font.iconSmall
          onClicked: row.removeRequested()
        }
      }
    }

    // The remove confirm replaces the header. Nothing is removed without
    // the second click.
    Rectangle {
      visible: row.confirming
      Layout.fillWidth: true
      implicitHeight: Math.max(Style.spacing.popupRowHeight, confirmRow.implicitHeight + Style.spacing.xxs * 2)
      radius: Style.cornerRadius
      color: Util.alpha(row.theme.urgent, 0.15)

      RowLayout {
        id: confirmRow
        anchors.fill: parent
        anchors.leftMargin: Style.spacing.rowPaddingX
        anchors.rightMargin: Style.spacing.xxs
        spacing: Style.spacing.md

        PlainText {
          Layout.fillWidth: true
          text: row.strings.t("removeAsk").arg(row.name)
          color: row.theme.foreground
          font.family: row.theme.fontFamily
          wrapMode: Text.WrapAnywhere
        }

        ConfirmButton {
          text: row.strings.t("cancel")
          foreground: row.theme.foreground
          onClicked: row.removeCancelled()
        }

        ConfirmButton {
          text: row.strings.t("remove")
          foreground: row.theme.urgent
          accent: row.theme.urgent
          onClicked: row.removeConfirmed()
        }
      }
    }

    ServerDetails {
      visible: row.open
      active: row.open
      Layout.fillWidth: true
      Layout.leftMargin: Style.spacing.rowPaddingX
      Layout.rightMargin: Style.spacing.rowPaddingX
      Layout.topMargin: Style.spacing.xs
      Layout.bottomMargin: Style.spacing.xxl
      theme: row.theme
      strings: row.strings
      server: row.server
      showDisks: row.showDisks
    }
  }

  component ConfirmButton: Button {
    fontFamily: row.theme.fontFamily
    fontSize: Style.font.bodySmall
    horizontalPadding: Style.spacing.lg
    verticalPadding: Style.spacing.xxs
    bordered: true
  }
}
