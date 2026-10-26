import QtQuick
import qs.Commons
import qs.Commons as Commons

// Every Text in this plugin shows server data or plugin strings, so none of
// it may be read as rich text.
Text {
  textFormat: Text.PlainText
  color: Commons.Color.foreground
  font.family: Style.font.family
  font.pixelSize: Style.font.body
}
