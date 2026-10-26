import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../common"
import "../form"
import "../row"
import "../logic/Config.js" as Config
import "../logic/Format.js" as Format

// What the panel shows: the header, the server list or the add-server form,
// and the footer. The panel builds it the first time it opens and keeps it
// after that (KeyboardPanel.content).
//
// The list state lives here: the view, the keyboard cursor and the remove
// confirm. The rows only show it and send their clicks back.
PanelKeyCatcher {
  id: root

  required property Theme theme
  required property var strings
  property var service: null
  property bool opened: false

  signal hideRequested()
  signal switchRequested(int direction)

  readonly property var servers: service ? service.servers : []
  readonly property var settings: service ? service.settings : Config.DEFAULT_SETTINGS
  // The most recent poll of any server, for the footer. 0 before the first.
  readonly property real lastPollMs: servers.reduce(function(latest, s) { return Math.max(latest, s.lastPollMs) }, 0)

  // A problem with config.json, shown under the title: the file is not
  // valid JSON, or servers in it were skipped (Config.read).
  readonly property string notice: {
    if (!service) return ""
    if (service.configInvalid) return strings.t("config.invalid")
    var skipped = service.skipped
    if (skipped.length === 0) return ""
    var list = skipped.map(function(s) {
      return (s.name || "#" + s.index) + " (" + strings.t("config.reason." + s.reason) + ")"
    }).join(", ")
    return strings.tn("config.skipped", skipped.length).arg(Commons.I18n.formatNumber(skipped.length)).arg(list)
  }

  // "list" shows the servers; "add" shows the add-server form in their place.
  property string view: "list"
  property string confirmName: ""
  property bool cursorActive: false
  property int cursorIndex: 0

  function refresh() {
    if (service) service.pollAll()
  }

  function toggleRow(server) {
    if (service) service.setOpen(server.name, !server.open)
  }

  function setCursor(index) {
    cursorActive = true
    cursorIndex = index
  }

  // The first arrow key shows the cursor; the next ones move it.
  function moveCursor(dy) {
    if (servers.length === 0 || dy === 0) return
    if (!cursorActive) { cursorActive = true; return }
    cursorIndex = Math.max(0, Math.min(servers.length - 1, cursorIndex + dy))
  }

  // Enter opens or closes the row under the cursor, or confirms its remove.
  function activateCursor() {
    if (!cursorActive || servers.length === 0) return
    var server = servers[cursorIndex]
    if (confirmName === server.name) removeServer(server.name)
    else toggleRow(server)
  }

  function askRemoveAtCursor() {
    if (cursorActive && servers.length > 0) confirmName = servers[cursorIndex].name
  }

  // Removes the server from config.json. Its key line stays on the server;
  // `remote-stats remove` removes both.
  function removeServer(name) {
    if (service) service.removeServer(name)
    confirmName = ""
    cursorIndex = Math.max(0, Math.min(cursorIndex, servers.length - 1))
  }

  function openForm() {
    confirmName = ""
    addForm.reset()
    view = "add"
    Qt.callLater(addForm.focusFirst)
  }

  function closeForm() {
    view = "list"
    forceActiveFocus()
  }

  // The server shows as Connecting until its first poll answers.
  function saveServer(entry) {
    if (service && service.addServer(entry)) closeForm()
  }

  onOpenedChanged: if (opened) {
    cursorActive = false
    confirmName = ""
    if (view === "add") Qt.callLater(addForm.focusFirst)
  }

  implicitHeight: header.implicitHeight + Style.spacing.panelGap + list.contentHeight
    + (footer.visible ? Style.spacing.panelGap + footer.implicitHeight : 0)

  // The form's text fields take the keys; Esc in a field closes the form.
  blocked: view === "add"
  onMoveRequested: function(dx, dy) { moveCursor(dy) }
  onActivateRequested: activateCursor()
  onDeleteRequested: askRemoveAtCursor()
  onCloseRequested: {
    if (confirmName !== "") confirmName = ""
    else hideRequested()
  }
  onTabRequested: function(direction) { switchRequested(direction) }
  onTextKey: function(t) {
    if (t === "r" || t === "R") refresh()
  }

  PanelHeader {
    id: header
    width: parent.width
    theme: root.theme
    strings: root.strings
    view: root.view
    serverCount: root.servers.length
    notice: root.notice
    onRefreshRequested: root.refresh()
    onAddRequested: root.openForm()
    onFormCloseRequested: root.closeForm()
  }

  // Only the list scrolls; the header and the footer stay in place.
  Flickable {
    id: list
    anchors.top: header.bottom
    anchors.topMargin: Style.spacing.panelGap
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: footer.visible ? footer.top : parent.bottom
    anchors.bottomMargin: footer.visible ? Style.spacing.panelGap : 0
    contentWidth: width
    contentHeight: root.view === "add" ? addForm.implicitHeight : listColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: listColumn
      visible: root.view === "list"
      width: list.width
      spacing: Style.spacing.xxs

      // The model is the count, not the array: each poll makes a new
      // array, and an array model would rebuild every row. With the
      // count, rows stay and only their data changes.
      Repeater {
        model: root.servers.length

        delegate: ServerRow {
          required property int index
          width: listColumn.width
          theme: root.theme
          strings: root.strings
          server: root.servers[index] || ({})
          confirming: root.confirmName === name
          hasCursor: root.cursorActive && root.cursorIndex === index
          showDisks: root.settings.showDisks
          onToggleRequested: root.toggleRow(server)
          onRemoveRequested: root.confirmName = name
          onRemoveConfirmed: root.removeServer(name)
          onRemoveCancelled: root.confirmName = ""
          onHovered: root.setCursor(index)
        }
      }

      EmptyState {
        visible: root.servers.length === 0
        width: parent.width
        theme: root.theme
        strings: root.strings
        interval: root.settings.interval
      }
    }

    AddServerForm {
      id: addForm
      visible: root.view === "add"
      width: list.width
      theme: root.theme
      strings: root.strings
      service: root.service
      names: root.servers.map(function(s) { return s.name })
      onCloseRequested: root.closeForm()
      onSaveRequested: function(entry) { root.saveServer(entry) }
    }
  }

  // When the servers were last polled, always in view below the list, so a
  // glance tells how fresh the numbers are.
  PlainText {
    id: footer
    visible: root.view === "list" && root.lastPollMs > 0
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    text: root.strings.t("lastPoll")
      .arg(Format.clock(root.lastPollMs, true))
      .arg(Commons.I18n.formatNumber(root.settings.interval))
    color: root.theme.dim
    font.family: root.theme.fontFamily
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignHCenter
  }
}
