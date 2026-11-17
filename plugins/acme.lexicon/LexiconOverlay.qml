import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false
  property var matches: []
  property string statusMessage: "Type a word pattern, rack letters, or substring"
  property string definitionText: ""
  property bool searchRunning: false
  property int searchGeneration: 0
  property bool searchQueued: false

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Commons.Color.menu.scrim
  property color selectedBackground: Commons.Color.menu.selectedBackground
  property color selectedText: Commons.Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int cardWidth: Math.min(Style.space(640), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(520), panel.height - Style.gapsOut * 2)
  property int rowHeight: Math.max(Style.space(36), Style.font.body + Style.spacing.rowPaddingX)

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") || ({}) }
    catch (error) { payload = ({}) }
    var query = ""
    if (typeof payload.query === "string") query = payload.query.slice(0, 80)
    root.opened = true
    root.selectedIndex = 0
    root.cursorActive = false
    root.matches = []
    root.definitionText = ""
    root.setFilter(query)
    Qt.callLater(function() { filterInput.forceActiveFocus() })
  }

  function close() {
    root.opened = false
    root.searchRunning = false
    root.searchQueued = false
    root.searchGeneration += 1
    searchDebounce.stop()
    searchProc.running = false
    definitionProc.running = false
    definitionNotifyProc.running = false
  }

  function dismiss() {
    root.opened = false
    root.searchRunning = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "acme.lexicon")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function setFilter(next) {
    root.filterText = next
    if (filterInput.text !== next) filterInput.text = next
    root.selectedIndex = 0
    root.cursorActive = false
    root.definitionText = ""
    root.scheduleSearch()
  }

  property Timer searchDebounce: Timer {
    interval: 180
    repeat: false
    onTriggered: root.runSearch()
  }

  function scheduleSearch() {
    searchDebounce.restart()
  }

  readonly property string searchScript: (root.manifest && root.manifest.__sourceDir)
    ? root.manifest.__sourceDir + "/search.py"
    : Qt.resolvedUrl("search.py").toString().replace("file://", "")

  function runSearch() {
    if (!root.opened) return
    var query = root.filterText.trim()
    if (query.length === 0) {
      root.searchQueued = false
      root.searchGeneration += 1
      root.searchRunning = false
      root.matches = []
      root.statusMessage = strings.t("search.hint")
      return
    }
    if (searchProc.running) {
      root.searchQueued = true
      return
    }
    root.searchQueued = false
    root.searchGeneration += 1
    root.searchRunning = true
    root.statusMessage = strings.t("search.running")
    searchProc.command = [
      "python3",
      root.searchScript,
      "--query", query,
      "--sort", "alpha",
      "--limit", "50"
    ]
    searchProc.running = true
  }

  function applySearchResult(text, generation) {
    var followUp = root.searchQueued
    root.searchQueued = false
    if (generation !== root.searchGeneration || !root.opened) {
      if (followUp && root.opened) root.runSearch()
      return
    }
    root.searchRunning = false
    try {
      var payload = JSON.parse(text || "{}")
      if (!payload || payload.ok === false) {
        root.matches = []
        var detail = payload && payload.error ? String(payload.error).split("\n")[0] : strings.t("search.error")
        root.statusMessage = detail.slice(0, 160)
      } else {
        root.matches = payload.results || []
        if (root.matches.length === 0) {
          root.statusMessage = strings.t("results.none").arg(root.filterText)
        } else {
          root.statusMessage = strings.tn("results.count", root.matches.length).arg(Commons.I18n.formatNumber(root.matches.length))
        }
        root.selectedIndex = 0
        if (root.matches.length > 0) root.fetchDefinition(root.matches[0])
      }
    } catch (error) {
      root.matches = []
      root.statusMessage = strings.t("search.error")
    }
    if (followUp) root.runSearch()
  }

  function select(delta) {
    if (root.matches.length === 0) return
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? root.matches.length - 1 : 0
    } else {
      selectedIndex = (selectedIndex + delta + root.matches.length) % root.matches.length
    }
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
    root.fetchDefinition(root.matches[selectedIndex] || "")
  }

  function activateIndex(index) {
    if (index < 0 || index >= root.matches.length) return
    var word = root.matches[index]
    if (!word) return
    root.copyWord(word)
  }

  function copyWord(word) {
    root.dismiss()
    Quickshell.execDetached(["wl-copy", word])
    root.fetchDefinitionAsync(word)
  }

  function fetchDefinition(word) {
    if (!word) { root.definitionText = ""; return }
    definitionProc.command = ["dict", "-d", "wn", word]
    definitionProc.running = true
  }

  function fetchDefinitionAsync(word) {
    if (!word) return
    definitionNotifyProc.command = ["dict", "-d", "wn", word]
    definitionNotifyProc.running = true
  }

  Process {
    id: searchProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySearchResult(text, root.searchGeneration)
    }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: {} }
  }

  Process {
    id: definitionProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.definitionText = text.trim() || ""
      }
    }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: {} }
  }

  Process {
    id: definitionNotifyProc
    running: false
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: {} }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: {} }
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "omarchy-lexicon"

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.cursorActive) root.activateIndex(root.selectedIndex)
            else if (root.matches.length > 0) { root.cursorActive = true; root.selectedIndex = 0 }
            event.accepted = true
          }
        }

        Column {
          anchors.fill: parent
          anchors.topMargin: card.contentTopInset
          anchors.rightMargin: card.contentRightInset
          anchors.bottomMargin: card.contentBottomInset
          anchors.leftMargin: card.contentLeftInset
          spacing: root.contentSpacing

          Row {
            width: parent.width
            height: root.headerHeight
            spacing: Style.space(12)

            Item {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - statusLabel.width - parent.spacing
              height: parent.height

              FilterInput {
                id: filterInput
                anchors.fill: parent
                keyHandler: keyCatcher
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                onTextChanged: if (text !== root.filterText) root.setFilter(text)
              }

              Text {
                textFormat: Text.PlainText
                anchors.fill: filterInput
                verticalAlignment: Text.AlignVCenter
                visible: !root.filterText && !filterInput.preeditText
                text: strings.t("search.hint")
                color: root.foreground
                opacity: 0.58
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                elide: Text.ElideRight
              }
            }

            Text {
              id: statusLabel
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: root.searchRunning ? "…" : root.statusMessage
              color: root.foreground
              opacity: 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          Row {
            width: parent.width
            height: parent.height - root.headerHeight - root.contentSpacing

            ListView {
              id: resultList
              width: root.definitionText ? parent.width / 2 - Style.space(8) : parent.width
              height: parent.height
              model: root.matches
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              delegate: Rectangle {
                required property int index
                required property string modelData

                readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex

                width: ListView.view.width
                height: root.rowHeight
                radius: root.cornerRadius
                color: hasCursor ? root.selectedBackground : "transparent"

                Text {
                  textFormat: Text.PlainText
                  anchors.verticalCenter: parent.verticalCenter
                  x: Style.space(10)
                  width: parent.width - Style.space(20)
                  text: parent.modelData
                  color: parent.hasCursor ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  elide: Text.ElideRight
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onContainsMouseChanged: if (containsMouse) {
                    root.cursorActive = true
                    root.selectedIndex = index
                    root.fetchDefinition(modelData)
                  }
                  onClicked: {
                    root.cursorActive = true
                    root.selectedIndex = index
                    root.activateIndex(index)
                  }
                }
              }

              Column {
                anchors.centerIn: parent
                width: parent.width - 2 * root.contentMargin
                spacing: Style.space(8)
                visible: root.matches.length === 0 && !root.searchRunning && root.filterText.length > 0

                Text {
                  text: "󰾹"
                  color: root.selectedText
                  opacity: 0.6
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.displayLarge
                  horizontalAlignment: Text.AlignHCenter
                  width: parent.width
                }

                Text {
                  textFormat: Text.PlainText
                  text: strings.t("results.none").arg(root.filterText)
                  color: root.foreground
                  opacity: 0.6
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  horizontalAlignment: Text.AlignHCenter
                  width: parent.width
                  elide: Text.ElideRight
                }
              }
            }

            Item {
              visible: root.definitionText.length > 0
              width: parent.width / 2 - Style.space(8)
              height: parent.height

              Rectangle {
                width: Style.normalBorderWidth
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                color: Util.alpha(root.border, 0.28)
              }

              Text {
                textFormat: Text.PlainText
                anchors.fill: parent
                anchors.leftMargin: root.contentMargin
                anchors.topMargin: 0
                text: root.definitionText
                color: root.foreground
                opacity: 0.85
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                verticalAlignment: Text.AlignTop
                clip: true
              }
            }
          }
        }
      }
    }
  }
}
