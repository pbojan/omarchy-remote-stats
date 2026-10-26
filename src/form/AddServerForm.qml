import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../common"
import "../logic/Config.js" as Config
import "../logic/Format.js" as Format
import "../logic/Poll.js" as Poll
import "../logic/Target.js" as Target
import "../logic/TestChecks.js" as TestChecks

// Add-server form, shown in the panel in place of the server list. Fields are
// checked as you type. Test runs ssh-keygen on the key, then one poll as the
// service runs it, with a new login, and shows the result as five checks.
ColumnLayout {
  id: form

  required property Theme theme
  required property var strings
  // The service builds the test command; the form only runs it.
  property var service: null
  // The names already in the list, for the duplicate check.
  property var names: []

  signal closeRequested()
  signal saveRequested(var entry)

  readonly property string localUser: Quickshell.env("USER") || ""
  readonly property string targetText: targetField.text.trim()
  readonly property string keyText: keyField.text.trim()
  readonly property var parsed: Target.parseTarget(targetText)
  readonly property bool targetOk: parsed.err === ""
  readonly property string name: Target.effectiveName(nameField.text, targetText)
  readonly property bool duplicate: name !== "" && names.indexOf(name) >= 0
  readonly property bool valid: targetOk && name !== "" && !duplicate && keyText !== ""

  property bool tested: false
  property bool running: false
  property var keyResult: null
  property var pollResult: null
  readonly property var results: tested ? TestChecks.checks(targetText, keyResult, pollResult) : []
  readonly property bool failed: tested && !running && results.some(function(c) { return c.status === "fail" })
  readonly property bool passed: tested && !running && !failed

  function reset() {
    clearTest()
    targetField.text = ""
    nameField.text = ""
    keyField.text = Config.DEFAULT_KEY
  }

  function focusFirst() { targetField.input.forceActiveFocus() }

  // Any edit makes an earlier test result meaningless. `running` goes false
  // first, so a process that exits after this changes nothing.
  function clearTest() {
    running = false
    keyCheck.running = false
    poll.running = false
    tested = false
    keyResult = null
    pollResult = null
  }

  function test() {
    if (!targetOk || running || !service) return
    clearTest()
    tested = true
    if (keyText === "") {
      keyResult = { exitCode: 1, stderr: "" }
      return
    }
    running = true
    keyCheck.command = ["ssh-keygen", "-y", "-P", "", "-f", Target.expandHome(keyText, service.home)]
    keyCheck.running = true
  }

  function save() {
    if (!valid || running) return
    saveRequested({ name: name, target: targetText, key: keyText })
  }

  // What the checklist shows for each check.
  readonly property var checks: results.map(function(c) {
    var done = c.status === "ok" || c.status === "fail"
    return {
      status: c.status,
      text: done ? checkText(c) : strings.t("check." + c.check),
      detail: done ? checkDetail(c) : "",
      hint: checkHint(c)
    }
  })

  function checkText(c) {
    if (c.check === "glances" && c.status === "ok")
      return strings.t("check.glancesPassed").arg(c.hostname).arg(Format.percent(c.cpu, Commons.I18n.formatNumber))
    if (c.kind === "glances-missing") return strings.t("check.glancesMissing")
    if (c.kind === "glances") return strings.t("glancesFailed")
    if (c.kind === "timeout") return strings.t("timedOut").arg(Commons.I18n.formatNumber(Poll.DEADLINE_SECONDS))
    return strings.t("check." + c.check)
  }

  function checkDetail(c) {
    if (c.detail) return c.detail
    return c.status === "fail" && c.kind === "key" ? strings.t("check.noKey") : ""
  }

  function checkHint(c) {
    if (c.status !== "fail") return ""
    if (c.kind === "key") return strings.t("hint.key")
    if (c.kind === "server") return strings.t("hint.server")
    if (c.kind === "hostkey") return strings.t("hint.hostkey").arg(parsed.host)
    if (c.kind === "auth") {
      var keyName = keyText.split("/").pop()
      return strings.t("hint.auth").arg(keyName).arg(parsed.user || localUser)
    }
    if (c.kind === "glances-missing") return strings.t("hint.glances")
    if (c.kind === "glances") return strings.t("hint.glancesFailed")
    if (c.kind === "timeout") return strings.t("hint.timedOut")
    return ""
  }

  function targetError() {
    if (targetText === "" || targetOk) return ""
    return strings.t("form.err." + parsed.err)
  }

  function targetHelp() {
    if (!targetOk) return strings.t("form.targetHelp")
    var user = parsed.user !== "" ? parsed.user : localUser
    return strings.t("form.connectsAs").arg(user).arg(parsed.host).arg(Commons.I18n.formatNumber(parsed.port))
  }

  spacing: Style.spacing.panelGap

  // Check 2: the key loads without a passphrase.
  Process {
    id: keyCheck
    stderr: StdioCollector { id: keyErr }
    onExited: function(exitCode) {
      if (!form.running) return
      form.keyResult = { exitCode: exitCode, stderr: keyErr.text }
      if (exitCode !== 0) {
        form.running = false
        return
      }
      poll.command = form.service.testCommand({ target: form.targetText, key: form.keyText })
      poll.running = true
    }
  }

  // Checks 3 to 5: one poll, with a new login.
  Process {
    id: poll
    stdout: StdioCollector { id: pollOut }
    stderr: StdioCollector { id: pollErr }
    onExited: function(exitCode) {
      if (!form.running) return
      form.pollResult = { exitCode: exitCode, stdout: pollOut.text, stderr: pollErr.text }
      form.running = false
    }
  }

  PanelSeparator {
    Layout.fillWidth: true
    foreground: form.theme.foreground
  }

  PanelSectionHeader {
    Layout.fillWidth: true
    text: form.strings.t("addServer")
    foreground: form.theme.foreground
    fontFamily: form.theme.fontFamily
  }

  GridLayout {
    Layout.fillWidth: true
    columns: 2
    columnSpacing: Style.spacing.xxl
    rowSpacing: Style.spacing.rowGap

    FieldLabel { text: form.strings.t("form.target") }

    Field {
      id: targetField
      ltr: true
      placeholderText: form.strings.t("form.targetPlaceholder")
      help: form.targetHelp()
      error: form.targetError()
    }

    FieldLabel { text: form.strings.t("form.name") }

    Field {
      id: nameField
      placeholderText: form.targetOk ? form.parsed.host : form.strings.t("form.namePlaceholder")
      error: form.duplicate ? form.strings.t("form.err.duplicate").arg(form.name) : ""
    }

    FieldLabel { text: form.strings.t("form.key") }

    Field {
      id: keyField
      ltr: true
      text: Config.DEFAULT_KEY
      placeholderText: Config.DEFAULT_KEY
      help: form.strings.t("form.keyHelp")
      error: form.keyText === "" ? form.strings.t("form.err.required") : ""
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.md

    FormButton {
      text: form.running ? form.strings.t("form.testing") : form.strings.t("form.test")
      iconText: "󰄬"
      iconSize: Style.font.iconSmall
      enabled: form.targetOk && !form.running && form.service !== null
      onClicked: form.test()
    }

    Item { Layout.fillWidth: true }

    FormButton {
      text: form.strings.t("form.save")
      background: form.passed ? form.theme.hoverFill : "transparent"
      enabled: form.valid && !form.running
      onClicked: form.save()
    }
  }

  ColumnLayout {
    visible: form.tested
    Layout.fillWidth: true
    spacing: Style.spacing.panelGap

    PanelSeparator {
      Layout.fillWidth: true
      foreground: form.theme.foreground
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.lg

      PanelSectionHeader {
        Layout.fillWidth: true
        text: form.strings.t("test.header")
        foreground: form.theme.foreground
        fontFamily: form.theme.fontFamily
      }

      PanelSectionHeader {
        text: form.running ? form.strings.t("test.running")
          : (form.failed ? form.strings.t("test.failed") : form.strings.t("test.passed"))
        foreground: form.failed ? form.theme.urgent : form.theme.foreground
        fontFamily: form.theme.fontFamily
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.xs

      Repeater {
        model: form.checks

        delegate: TestCheck {
          required property var modelData
          Layout.fillWidth: true
          theme: form.theme
          status: modelData.status
          text: modelData.text
          detail: modelData.detail
          hint: modelData.hint
        }
      }
    }
  }

  // A label in the first grid column, level with its field.
  component FieldLabel: PlainText {
    Layout.alignment: Qt.AlignTop
    Layout.preferredHeight: Style.spacing.controlHeight
    verticalAlignment: Text.AlignVCenter
    color: form.theme.foreground
    font.family: form.theme.fontFamily
  }

  // Any edit clears the test; Enter tests; Esc closes the form.
  component Field: FormField {
    Layout.fillWidth: true
    theme: form.theme
    onTextChanged: form.clearTest()
    onAccepted: form.test()
    onEscapePressed: form.closeRequested()
  }

  component FormButton: Button {
    fontSize: Style.font.bodySmall
    foreground: form.theme.foreground
    fontFamily: form.theme.fontFamily
    horizontalPadding: Style.spacing.rowPaddingX
    bordered: true
    opacity: enabled ? 1 : 0.5
  }
}
