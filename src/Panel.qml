import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "common"
import "panel"
import "logic/Status.js" as Status

// Remote Stats bar widget: the bar glyph and its panel. The servers come
// from the service (Service.qml), which polls them once for all bars.
Panel {
  id: root
  moduleName: "pbojan.remote-stats"
  ipcTarget: "pbojan.remote-stats"

  property var service: null
  readonly property var servers: service ? service.servers : []
  readonly property bool attention: servers.some(function(s) { return Status.needsAttention(s.status) })
  // Also true with no servers.
  readonly property bool waiting: servers.every(function(s) { return s.status === "connecting" })

  // The service is shared by the bars on all monitors. The shell may load it
  // after this widget, so look again until it is there.
  function bindService() {
    var shell = bar && bar.shell ? bar.shell : null
    if (shell && typeof shell.serviceFor === "function") service = shell.serviceFor("pbojan.remote-stats")
  }

  onBarChanged: bindService()

  Timer {
    interval: 200
    running: root.service === null
    repeat: true
    onTriggered: root.bindService()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // One log line per load, so `journalctl --user -t omarchy-shell` shows
  // which code the shell is running.
  Component.onCompleted: console.log("pbojan.remote-stats: widget loaded")

  Theme {
    id: barTheme
    bar: root.bar
  }

  Commons.Translations {
    id: translations
    directory: Qt.resolvedUrl("i18n")
  }

  BarButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    attention: root.attention
    waiting: root.waiting
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    padding: Style.spacing.panelPadding
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelContent {
      anchors.fill: parent
      theme: barTheme
      strings: translations
      service: root.service
      opened: root.opened
      onHideRequested: root.close()
      onSwitchRequested: function(direction) { root.switchPanel(direction) }
    }
  }
}
