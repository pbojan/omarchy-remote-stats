import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../common"
import "../logic/Format.js" as Format
import "../logic/Poll.js" as Poll
import "../logic/Status.js" as Status

// The open part of a server row, by status:
//   data        Connected, Critical, Stale: the distribution and the data points
//   issue       Glances is missing, failed or did not answer in time
//   offline     the SSH error as is, and when the server last answered
//   connecting  empty meters until the first poll
// The row builds it only while it is open. A poll that keeps the kind
// updates the values in place, so the meters glide instead of rebuilding.
Loader {
  id: root

  required property Theme theme
  required property var strings
  property var server: ({})
  property bool showDisks: true

  readonly property string status: server.status || "connecting"
  // Never null: while the loader switches views, the data view may read it
  // once more after its server lost the snapshot.
  readonly property var snapshot: server.snapshot || ({ cpu: {}, mem: {}, fs: [] })
  readonly property var fmt: Commons.I18n.formatNumber

  sourceComponent: Status.hasData(status) ? dataView
    : status === "issue" ? issueView
    : status === "offline" ? offlineView
    : connectingView

  Component {
    id: dataView

    ColumnLayout {
      id: dataPoints
      readonly property var disks: Status.uniqueDisks(root.snapshot.fs)

      spacing: Style.spacing.rowGap

      PlainText {
        visible: text !== ""
        Layout.fillWidth: true
        text: Format.distroName(root.snapshot)
        color: root.theme.foreground
        font.family: root.theme.fontFamily
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
      }

      MetricRow {
        Layout.fillWidth: true
        theme: root.theme
        label: root.strings.t("load")
        value: Format.loadAverage(root.snapshot.load, root.fmt)
        caption: root.snapshot.load
          ? root.strings.tn("loadCaption", root.snapshot.load.cpucore).arg(root.fmt(root.snapshot.load.cpucore))
          : ""
      }

      PercentRow {
        label: root.strings.t("cpu")
        percent: root.snapshot.cpu.total
      }

      PercentRow {
        label: root.strings.t("memory")
        percent: root.snapshot.mem.percent
        caption: Format.usedTotal(root.snapshot.mem.used, root.snapshot.mem.total, root.fmt)
      }

      PanelSectionHeader {
        visible: root.showDisks && dataPoints.disks.length > 0
        Layout.fillWidth: true
        Layout.topMargin: Style.spacing.xs
        text: root.strings.t("disks")
        foreground: root.theme.foreground
        fontFamily: root.theme.fontFamily
      }

      // The count as the model, so a poll updates the disk rows in place
      // instead of rebuilding them. showDisks hides the rows only: a full
      // disk still makes the server Critical.
      Repeater {
        model: root.showDisks ? dataPoints.disks.length : 0

        delegate: PercentRow {
          required property int index
          readonly property var disk: dataPoints.disks[index] || ({})
          label: Format.diskLabel(disk)
          percent: disk.percent
          caption: Format.usedTotal(disk.used, disk.size, root.fmt)
        }
      }

      PlainText {
        visible: root.status === "stale"
        text: root.strings.t("staleSince").arg(Format.clock(root.server.lastOkMs, true))
        color: root.theme.urgent
        font.family: root.theme.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  Component {
    id: issueView

    // One view for the three error kinds of an Issue (Poll.failure).
    ColumnLayout {
      id: issue
      readonly property var failure: root.server.error || ({ kind: "", message: "" })
      spacing: Style.spacing.labelGap

      PlainText {
        text: issue.failure.kind === "timeout" ? root.strings.t("timedOut").arg(root.fmt(Poll.DEADLINE_SECONDS))
          : issue.failure.kind === "glances" ? root.strings.t("glancesFailed")
          : root.strings.t("glancesMissing")
        color: root.theme.foreground
        font.family: root.theme.fontFamily
      }

      // What Glances printed on stderr, as is.
      PlainText {
        visible: issue.failure.kind === "glances" && issue.failure.message !== ""
        Layout.fillWidth: true
        text: issue.failure.message
        color: root.theme.foreground
        font.family: root.theme.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WrapAnywhere
      }

      PlainText {
        Layout.fillWidth: true
        text: root.strings.t(issue.failure.kind === "timeout" ? "timedOutHint"
          : issue.failure.kind === "glances" ? "glancesFailedHint"
          : "glancesHint").arg(root.server.name)
        color: root.theme.dim
        font.family: root.theme.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }
    }
  }

  Component {
    id: offlineView

    ColumnLayout {
      spacing: Style.spacing.labelGap

      PlainText {
        Layout.fillWidth: true
        text: root.server.error ? root.server.error.message : ""
        color: root.theme.foreground
        font.family: root.theme.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WrapAnywhere
      }

      PlainText {
        text: root.server.lastOkMs > 0
          ? root.strings.t("lastSeen").arg(Format.clock(root.server.lastOkMs, false))
          : root.strings.t("neverSeen")
        color: root.theme.dim
        font.family: root.theme.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  Component {
    id: connectingView

    ColumnLayout {
      spacing: Style.spacing.rowGap

      WaitingRow { label: root.strings.t("cpu") }
      WaitingRow {
        label: root.strings.t("memory")
        caption: root.strings.t("waiting")
      }
    }
  }

  // A percent with its meter, urgent from 90 %.
  component PercentRow: MetricRow {
    Layout.fillWidth: true
    theme: root.theme
    meter: true
    value: Format.percent(percent, root.fmt)
    critical: Status.isCritical(percent)
  }

  // An empty track and a dash, before the first poll.
  component WaitingRow: MetricRow {
    Layout.fillWidth: true
    theme: root.theme
    meter: true
    value: "–"
    faintValue: true
  }
}
