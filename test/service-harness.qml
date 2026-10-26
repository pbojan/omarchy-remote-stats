import QtQuick
import Quickshell
import Quickshell.Io

// Runs the plugin's Service without the Omarchy shell, for test/cli.test.sh.
// The test copies this file, src/Service.qml and src/logic/ into one folder.
// Prints one RESULT line when every server has been polled once, then adds
// removes and opens a server the way the panel does. Then it changes
// config.json the way an editor does, prints one STEP line after each
// change, and quits.
ShellRoot {
  Service {
    id: service

    property bool polled: false

    onResultsChanged: {
      if (polled || service.servers.length === 0 || !service.servers.every(function(s) { return s.lastPollMs > 0 })) return
      polled = true
      console.log("RESULT " + JSON.stringify({
        settings: service.settings,
        servers: service.servers.map(function(s) {
          return { name: s.name, status: s.status, error: s.error, cpu: s.snapshot ? s.snapshot.cpu.total : null }
        })
      }))

      // What the panel does on Save and on Remove.
      service.addServer({ name: "from-panel", target: "someone@127.0.0.1:1", key: "~/.ssh/remote_stats_ed25519" })
      service.removeServer("down")
      service.setOpen("test-box", true)
      editor.next()
    }
  }

  // Each step changes config.json with sh ($1 is its path; config.json.keep
  // holds the file as the panel left it). The last step puts it back.
  Process {
    id: editor

    readonly property var steps: [
      // Vim and Neovim: rename the file away, write the new one later.
      ["editor-save", "cp \"$1\" \"$1.keep\"; mv \"$1\" \"$1~\"; sleep 0.5; [ -e \"$1\" ] && echo wrote-defaults; mv \"$1~\" \"$1\""],
      ["invalid", "printf '{ \"servers\": [' > \"$1\""],
      ["skipped", "jq '.servers += [{name: \"bad\", target: \"a b\"}, {name: \"test-box\", target: \"x@h\"}]' \"$1.keep\" > \"$1\""],
      ["restore", "cp \"$1.keep\" \"$1\"; rm \"$1.keep\""]
    ]
    property int step: -1

    function next() {
      step++
      if (step === steps.length) Qt.quit()
      else {
        command = ["sh", "-c", steps[step][1], "sh", service.configDir + "/config.json"]
        running = true
      }
    }

    stdout: StdioCollector { id: editorOut }
    // Give the file watch time to reload, then print what the service shows.
    onExited: settle.start()
  }

  Timer {
    id: settle
    interval: 1000
    onTriggered: {
      console.log("STEP " + JSON.stringify({
        step: editor.steps[editor.step][0],
        output: editorOut.text.trim(),
        servers: service.servers.map(function(s) { return s.name }),
        invalid: service.configInvalid,
        skipped: service.skipped
      }))
      editor.next()
    }
  }
}
