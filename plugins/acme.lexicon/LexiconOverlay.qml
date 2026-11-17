import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "session.js" as Session

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool stateReady: false
  property bool openWaiting: false
  property string pendingQuery: ""
  property string focusZone: "pattern"
  property string filterText: ""
  property int lengthValue: 0
  property bool rackOn: false
  property bool byLetters: false
  property bool descending: false
  property bool suppressFilter: false
  property int selectedIndex: 0
  property int thesaurusIndex: 0
  property bool thesaurusActive: false
  property var matches: []
  property var thesaurus: []
  property var history: []
  property var currentSession: Session.defaultSession()
  property int historyCursor: -1
  property string pendingWord: ""
  property string pendingThesaurus: ""
  property string statusMessage: ""
  property string definitionText: ""
  property string thesaurusMessage: ""
  property bool searchRunning: false
  property bool thesaurusRunning: false
  property int searchSerial: 0
  property int definitionSerial: 0
  property int thesaurusSerial: 0
  property var searchStreamHandler: null
  property var definitionStreamHandler: null
  property var thesaurusStreamHandler: null

  readonly property string stateDir: {
    var base = Quickshell.env("XDG_STATE_HOME")
    if (!base) base = (Quickshell.env("HOME") || "") + "/.local/state"
    return base + "/omarchy-lexicon"
  }
  readonly property string statePath: root.stateDir + "/overlay.json"
  readonly property string searchScript: Qt.resolvedUrl("search.py").toString().replace("file://", "")

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Commons.Color.menu.scrim
  property color selectedBackground: Commons.Color.menu.selectedBackground
  property color selectedText: Commons.Color.menu.selectedText
  property color accent: Commons.Color.accent
  readonly property int cornerRadius: Style.cornerRadius
  property string fontId: "theme"
  property real uiScale: 1
  property double scaleTick: 0
  property var fontOptions: ["theme", "Liberation Sans", "Liberation Serif", "Liberation Mono", "iA Writer Quattro S"]
  property int sizeSlot: root.optionHeight * 2 + Style.space(72)
  readonly property string fontFamily: root.fontId === "theme" || !root.fontId ? Style.font.menuFamily : root.fontId
  readonly property int textCaption: Math.max(1, Math.round(Style.font.caption * root.uiScale))
  readonly property int textBody: Math.max(1, Math.round(Style.font.body * root.uiScale))
  readonly property int textTitle: Math.max(1, Math.round(Style.font.title * root.uiScale))
  readonly property int textHeading: Math.max(1, Math.round(Style.font.heading * root.uiScale))
  function dp(value) { return Math.max(1, Math.round(Number(value) * root.uiScale)) }
  property int contentMargin: Math.max(1, Math.round(Style.spacing.panelPadding * root.uiScale))
  property int headerHeight: Math.max(Math.round(Style.space(40) * root.uiScale), root.textTitle + Math.round(Style.spacing.controlPaddingY * 2 * root.uiScale))
  property int hintHeight: root.textCaption + Math.round(Style.space(8) * root.uiScale)
  property int optionHeight: Math.max(Math.round(Style.space(40) * root.uiScale), root.textBody + Math.round(Style.space(16) * root.uiScale))
  property int contentSpacing: Math.max(1, Math.round(Style.spacing.md * root.uiScale))
  property int cardWidth: Math.max(1, Math.min(Math.round(Style.space(1080) * root.uiScale), panel.width - Style.gapsOut * 2))
  property int cardHeight: Math.max(1, Math.min(Math.round(Style.space(680) * root.uiScale), panel.height - Style.gapsOut * 2))
  property int rowHeight: Math.max(Math.round(Style.space(36) * root.uiScale), root.textBody + Math.round(Style.spacing.rowPaddingX * root.uiScale))
  readonly property var zones: ["pattern", "length", "rack", "letters", "sort", "words", "meaning", "thesaurus"]

  Timer {
    id: searchDebounce
    interval: 180
    repeat: false
    onTriggered: root.runSearch()
  }

  Process {
    id: stateDirProc
    command: ["mkdir", "-p", root.stateDir]
    running: true
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.restoreState(text())
    onLoadFailed: root.restoreState("")
  }

  function restoreState(raw) {
    if (root.stateReady) return
    var parsed = ({})
    try { parsed = JSON.parse(raw || "") || ({}) } catch (error) { parsed = ({}) }
    var state = Session.normalizeState(parsed)
    var appearance = Session.normalizeAppearance(parsed.appearance)
    root.history = state.history
    root.currentSession = state.current
    root.historyCursor = state.cursor
    root.fontId = appearance.font
    root.uiScale = appearance.scale
    root.stateReady = true
    if (root.openWaiting) {
      root.openWaiting = false
      root.finishOpen(root.pendingQuery)
    }
  }

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") || ({}) } catch (error) { payload = ({}) }
    var query = ""
    if (typeof payload.query === "string") query = payload.query.slice(0, 80)
    var wasOpen = root.opened
    root.opened = true
    if (!root.stateReady) {
      root.pendingQuery = query
      root.openWaiting = true
      return
    }
    if (!wasOpen) root.finishOpen(query)
    else {
      if (query) root.setPattern(query)
      Qt.callLater(function() { root.showZone("pattern") })
    }
  }

  function finishOpen(query) {
    var session = Session.cloneSession(root.currentSession)
    if (query) session.pattern = String(query).trim().slice(0, 80)
    root.applySession(session)
    Qt.callLater(function() { root.showZone("pattern") })
  }

  function captureSession() {
    return {
      pattern: root.filterText,
      length: root.lengthValue,
      rack: root.rackOn,
      byLetters: root.byLetters,
      descending: root.descending,
      selectedWord: root.selectedWord(),
      thesaurusWord: root.thesaurusActive ? root.currentThesaurusWord() : ""
    }
  }

  function appearanceState() {
    return Session.normalizeAppearance({ font: root.fontId, scale: root.uiScale })
  }

  function persist() {
    var saved = Session.rememberOnExit(root.history, root.captureSession())
    root.history = saved.history
    root.currentSession = saved.current
    root.historyCursor = saved.cursor
    saved.appearance = root.appearanceState()
    stateFile.setText(JSON.stringify(saved))
  }

  function persistAppearance() {
    stateFile.setText(JSON.stringify({
      history: root.history,
      current: Session.cloneSession(root.currentSession),
      cursor: root.historyCursor,
      appearance: root.appearanceState()
    }))
  }

  function stepScale(direction) {
    var now = Date.now()
    if (now - root.scaleTick < 80) return
    root.scaleTick = now
    var next = Session.stepScale(root.uiScale, direction)
    if (next === root.uiScale) return
    root.uiScale = next
    root.persistAppearance()
  }

  function zoomDirection(event) {
    if (!(event.modifiers & Qt.ControlModifier)) return 0
    if (event.modifiers & (Qt.AltModifier | Qt.MetaModifier)) return 0
    var text = String(event.text || "")
    var key = event.key
    var nativeKey = event.nativeVirtualKey || 0
    if (key === Qt.Key_Minus || key === Qt.Key_Underscore || text === "-" || text === "_" || nativeKey === 0x2d || nativeKey === 0xffad) return -1
    if (key === Qt.Key_Plus || key === Qt.Key_Equal || text === "+" || text === "=" || nativeKey === 0x3d || nativeKey === 0x2b || nativeKey === 0xffab) return 1
    return 0
  }

  function chooseFont(id) {
    var next = String(id || "theme")
    if (!next) next = "theme"
    root.fontId = next
    root.persistAppearance()
  }

  function fontChoiceLabel(id) {
    if (id === "Liberation Sans") return strings.t("option.font.sans")
    if (id === "Liberation Serif") return strings.t("option.font.serif")
    if (id === "Liberation Mono") return strings.t("option.font.mono")
    if (id === "iA Writer Quattro S") return strings.t("option.font.writer")
    return strings.t("option.font.theme")
  }

  function fontChoiceFamily(id) {
    return !id || id === "theme" ? Style.font.menuFamily : id
  }

  function resetScale() {
    if (root.uiScale === 1) return
    root.uiScale = 1
    root.persistAppearance()
  }

  function resetFont() {
    if (root.fontId === "theme") return
    root.fontId = "theme"
    root.persistAppearance()
  }

  function stopWork() {
    searchDebounce.stop()
    root.detachStream(searchOut, "search")
    root.detachStream(definitionOut, "definition")
    root.detachStream(thesaurusOut, "thesaurus")
    searchProc.running = false
    definitionProc.running = false
    thesaurusProc.running = false
    root.searchRunning = false
    root.thesaurusRunning = false
    root.searchSerial += 1
    root.definitionSerial += 1
    root.thesaurusSerial += 1
  }

  function close() {
    if (!root.opened) return
    root.persist()
    root.opened = false
    root.stopWork()
  }

  function dismiss() {
    if (!root.opened) return
    root.persist()
    root.opened = false
    root.stopWork()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "acme.lexicon")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function scheduleSearch() {
    if (root.opened) searchDebounce.restart()
  }

  function applySession(session) {
    var next = Session.cloneSession(session)
    root.suppressFilter = true
    root.filterText = next.pattern
    if (filterInput.text !== next.pattern) filterInput.text = next.pattern
    root.suppressFilter = false
    root.lengthValue = next.length
    root.rackOn = next.rack
    root.byLetters = next.byLetters === true
    root.descending = next.descending
    root.pendingWord = next.selectedWord
    root.pendingThesaurus = next.thesaurusWord
    root.thesaurusActive = next.thesaurusWord.length > 0
    root.scheduleSearch()
  }

  function setPattern(next) {
    var pattern = String(next || "").slice(0, 80)
    root.suppressFilter = true
    root.filterText = pattern
    if (filterInput.text !== pattern) filterInput.text = pattern
    root.suppressFilter = false
    root.pendingWord = ""
    root.pendingThesaurus = ""
    root.thesaurusActive = false
    root.scheduleSearch()
  }

  function setLength(value) {
    var next = Math.max(0, Math.min(32, value))
    if (next === root.lengthValue) return
    root.lengthValue = next
    root.pendingWord = root.selectedWord()
    root.scheduleSearch()
  }

  function setRack(value) {
    var applied = Session.applyRack(root.lengthValue, value)
    root.rackOn = applied.rack
    root.lengthValue = applied.length
    root.pendingWord = root.selectedWord()
    root.scheduleSearch()
  }

  function setByLetters(value) {
    root.byLetters = value === true
    root.pendingWord = root.selectedWord()
    root.scheduleSearch()
  }

  function setDescending(value) {
    root.descending = value
    root.pendingWord = root.selectedWord()
    root.scheduleSearch()
  }

  function resetSearch() {
    root.historyCursor = -1
    root.applySession(Session.defaultSession())
  }

  function cycleHistory(direction) {
    var moved = Session.moveHistory(root.history, root.historyCursor, direction)
    root.historyCursor = moved.cursor
    root.applySession(moved.session)
  }

  function selectedWord() {
    if (root.selectedIndex < 0 || root.selectedIndex >= root.matches.length) return ""
    return String(root.matches[root.selectedIndex] || "")
  }

  function currentThesaurusWord() {
    if (root.thesaurusIndex < 0 || root.thesaurusIndex >= root.thesaurus.length) return ""
    return String(root.thesaurus[root.thesaurusIndex] || "")
  }

  function findIndex(list, word) {
    if (!word || !list) return -1
    for (var index = 0; index < list.length; index++) {
      if (list[index] === word) return index
    }
    return -1
  }

  function showZone(zone) {
    if (root.zones.indexOf(zone) < 0) return
    root.focusZone = zone
    if (zone === "thesaurus" && root.thesaurus.length > 0) {
      root.thesaurusActive = true
      root.pendingThesaurus = root.currentThesaurusWord()
      root.fetchDefinition(root.pendingThesaurus)
    }
    if (zone === "pattern") {
      filterInput.forceActiveFocus()
      return
    }
    filterInput.focus = false
    var target = lengthFocus
    if (zone === "rack") target = rackFocus
    else if (zone === "letters") target = lettersFocus
    else if (zone === "sort") target = sortFocus
    else if (zone === "words") target = resultList
    else if (zone === "meaning") target = meaningFlick
    else if (zone === "thesaurus") target = thesaurusList
    target.forceActiveFocus()
  }

  function focusStep(delta) {
    var index = root.zones.indexOf(root.focusZone)
    if (index < 0) index = 0
    var next = (index + delta + root.zones.length) % root.zones.length
    root.showZone(root.zones[next])
  }

  function arrowTarget(zone, key) {
    if (key === Qt.Key_Right) {
      if (zone === "pattern") return "length"
      if (zone === "length") return "rack"
      if (zone === "rack") return "letters"
      if (zone === "letters") return "sort"
      if (zone === "words") return "meaning"
      if (zone === "meaning") return "thesaurus"
    }
    if (key === Qt.Key_Left) {
      if (zone === "length") return "pattern"
      if (zone === "rack") return "length"
      if (zone === "letters") return "rack"
      if (zone === "sort") return "letters"
      if (zone === "meaning") return "words"
      if (zone === "thesaurus") return "meaning"
    }
    if (key === Qt.Key_Down) {
      if (zone === "pattern") return "length"
      if (zone === "length") return "words"
      if (zone === "rack" || zone === "letters") return "meaning"
      if (zone === "sort") return "thesaurus"
    }
    if (key === Qt.Key_Up) {
      if (zone === "length" || zone === "rack" || zone === "letters" || zone === "sort") return "pattern"
      if (zone === "words") return "length"
      if (zone === "meaning") return "rack"
      if (zone === "thesaurus") return "sort"
    }
    return ""
  }

  function handleNavKey(event) {
    if (!root.opened) return
    var zoom = root.zoomDirection(event)
    if (zoom) {
      root.stepScale(zoom)
      event.accepted = true
      return
    }
    if (event.modifiers & Qt.ControlModifier) {
      if (event.key === Qt.Key_0 && (event.modifiers & Qt.ShiftModifier)) root.resetFont()
      else if (event.key === Qt.Key_0) root.resetScale()
      else if (event.key === Qt.Key_Backspace && (event.modifiers & Qt.ShiftModifier)) root.resetFont()
      else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) root.setDescending(!root.descending)
      else if (event.key === Qt.Key_Up) root.cycleHistory("up")
      else if (event.key === Qt.Key_Down) root.cycleHistory("down")
      else if (event.key === Qt.Key_Backspace) root.resetSearch()
      else if (event.key === Qt.Key_D) root.showZone("pattern")
      else if (event.key === Qt.Key_T) root.showZone("thesaurus")
      else if (event.key === Qt.Key_C) root.copyFocused(false)
      else return
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Escape) {
      root.dismiss()
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
      root.focusStep(-1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Tab) {
      root.focusStep(1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.copyFocused(true)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Space && (root.focusZone === "rack" || root.focusZone === "letters" || root.focusZone === "sort")) {
      if (root.focusZone === "rack") root.setRack(!root.rackOn)
      else if (root.focusZone === "letters") root.setByLetters(!root.byLetters)
      else root.setDescending(!root.descending)
      event.accepted = true
      return
    }
    if (root.focusZone === "length" && event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
      var digit = event.key - Qt.Key_0
      var grown = root.lengthValue * 10 + digit
      root.setLength(grown > 32 ? digit : grown)
      event.accepted = true
      return
    }
    if (root.focusZone === "length" && event.key === Qt.Key_Backspace) {
      root.setLength(Math.floor(root.lengthValue / 10))
      event.accepted = true
      return
    }
    if ((root.focusZone === "words" || root.focusZone === "thesaurus") && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
      var delta = event.key === Qt.Key_Down ? 1 : -1
      if (root.focusZone === "words") root.moveWord(delta)
      else root.moveThesaurus(delta)
      event.accepted = true
      return
    }
    if (root.focusZone === "meaning" && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
      if (event.key === Qt.Key_Up && meaningFlick.contentY <= 0) {
        root.showZone("rack")
        event.accepted = true
        return
      }
      var nextY = meaningFlick.contentY + (event.key === Qt.Key_Down ? root.rowHeight : -root.rowHeight)
      var limit = Math.max(0, meaningFlick.contentHeight - meaningFlick.height)
      meaningFlick.contentY = Math.max(0, Math.min(nextY, limit))
      event.accepted = true
      return
    }
    if (root.focusZone === "pattern" && event.key === Qt.Key_Left) {
      return
    }
    if (root.focusZone === "pattern" && event.key === Qt.Key_Right) {
      if ((event.modifiers & Qt.ShiftModifier) || filterInput.selectedText.length > 0 || filterInput.cursorPosition < filterInput.text.length)
        return
    }
    if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
      var target = root.arrowTarget(root.focusZone, event.key)
      if (target) root.showZone(target)
      event.accepted = true
    }
  }

  function moveWord(delta) {
    if (root.matches.length === 0 || (delta < 0 && root.selectedIndex <= 0)) {
      if (delta < 0) root.showZone("length")
      return
    }
    var next = root.selectedIndex + delta
    if (next < 0 || next >= root.matches.length) return
    root.selectedIndex = next
    root.thesaurusActive = false
    root.pendingThesaurus = ""
    root.pendingWord = root.selectedWord()
    root.fetchDefinition(root.pendingWord)
    root.fetchThesaurus(root.pendingWord)
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function moveThesaurus(delta) {
    if (root.thesaurus.length === 0 || (delta < 0 && root.thesaurusIndex <= 0)) {
      if (delta < 0) root.showZone("sort")
      return
    }
    var next = root.thesaurusIndex + delta
    if (next < 0 || next >= root.thesaurus.length) return
    root.thesaurusIndex = next
    root.thesaurusActive = true
    root.pendingThesaurus = root.currentThesaurusWord()
    root.fetchDefinition(root.pendingThesaurus)
    thesaurusList.positionViewAtIndex(root.thesaurusIndex, ListView.Contain)
  }

  function copyFocused(closeAfter) {
    var text = ""
    if (root.focusZone === "thesaurus") text = root.currentThesaurusWord()
    else if (root.focusZone === "pattern" && !closeAfter) text = root.filterText
    else if (root.focusZone === "words" || root.focusZone === "meaning") text = root.selectedWord()
    else text = root.selectedWord() || root.filterText
    if (!text) return
    Quickshell.execDetached(["wl-copy", text])
    if (closeAfter) root.dismiss()
  }

  function streamHandler(which) {
    if (which === "search") return root.searchStreamHandler
    if (which === "definition") return root.definitionStreamHandler
    return root.thesaurusStreamHandler
  }

  function storeStreamHandler(which, handler) {
    if (which === "search") root.searchStreamHandler = handler
    else if (which === "definition") root.definitionStreamHandler = handler
    else root.thesaurusStreamHandler = handler
  }

  function detachStream(collector, which) {
    var previous = root.streamHandler(which)
    if (!previous) return
    try { collector.streamFinished.disconnect(previous) } catch (error) {}
    root.storeStreamHandler(which, null)
  }

  function attachStream(collector, which, serial, consume) {
    root.detachStream(collector, which)
    var handler = function() {
      try { collector.streamFinished.disconnect(handler) } catch (error) {}
      if (root.streamHandler(which) === handler) root.storeStreamHandler(which, null)
      consume(collector.text || "", serial)
    }
    root.storeStreamHandler(which, handler)
    collector.streamFinished.connect(handler)
  }

  function runSearch() {
    if (!root.opened) return
    var args = Session.searchArgs(root.filterText, root.lengthValue, root.rackOn, root.descending, root.byLetters)
    if (!args.query && !args.rack && args.length <= 0) {
      root.clearSearch()
      return
    }
    root.searchSerial += 1
    var serial = root.searchSerial
    root.searchRunning = true
    root.statusMessage = strings.t("search.running")
    var command = [
      "python3", root.searchScript,
      "--query", args.query,
      "--sort", args.sort,
      "--limit", "80"
    ]
    if (args.length > 0) command.push("--length", String(args.length))
    if (args.rack) command.push("--rack", args.rack)
    if (searchProc.running) searchProc.running = false
    root.attachStream(searchOut, "search", serial, root.applySearchResult)
    searchProc.command = command
    searchProc.running = true
  }

  function clearSearch() {
    root.searchSerial += 1
    root.detachStream(searchOut, "search")
    searchProc.running = false
    root.searchRunning = false
    root.matches = []
    root.selectedIndex = 0
    root.definitionText = ""
    root.thesaurus = []
    root.thesaurusMessage = ""
    root.thesaurusRunning = false
    root.statusMessage = ""
  }

  function applySearchResult(text, serial) {
    if (serial !== root.searchSerial || !root.opened) return
    root.searchRunning = false
    var payload = ({})
    try { payload = JSON.parse(text || "{}") || ({}) }
    catch (error) {
      root.matches = []
      root.statusMessage = strings.t("search.error")
      return
    }
    if (!payload || payload.ok === false) {
      root.matches = []
      var detail = payload && payload.error ? String(payload.error).split("\n")[0] : strings.t("search.error")
      root.statusMessage = detail.slice(0, 160)
      root.definitionText = ""
      root.thesaurus = []
      return
    }
    root.matches = payload.results || []
    var found = root.findIndex(root.matches, root.pendingWord)
    root.selectedIndex = found >= 0 ? found : 0
    if (root.matches.length === 0) {
      root.statusMessage = strings.t("results.none").arg(root.filterText)
      root.definitionText = ""
      root.thesaurus = []
      root.thesaurusMessage = ""
      return
    }
    root.statusMessage = strings.tn("results.count", root.matches.length).arg(Commons.I18n.formatNumber(root.matches.length))
    var word = root.selectedWord()
    root.fetchDefinition(root.pendingThesaurus || word)
    root.fetchThesaurus(word)
    Qt.callLater(function() {
      if (resultList.count > root.selectedIndex) resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
  }

  function fetchDefinition(word) {
    if (!word) {
      root.definitionText = ""
      return
    }
    root.definitionText = strings.t("meaning.looking")
    root.definitionSerial += 1
    var serial = root.definitionSerial
    if (definitionProc.running) definitionProc.running = false
    root.attachStream(definitionOut, "definition", serial, root.applyDefinition)
    definitionProc.command = ["python3", root.searchScript, "--definition", word]
    definitionProc.running = true
  }

  function applyDefinition(text, serial) {
    if (serial !== root.definitionSerial || !root.opened) return
    var payload = ({})
    try { payload = JSON.parse(text || "{}") || ({}) }
    catch (error) { payload = ({ ok: false, error: String(text || strings.t("meaning.unavailable")) }) }
    if (!payload.ok) {
      root.definitionText = String(payload.error || strings.t("meaning.unavailable")).slice(0, 500)
      return
    }
    root.definitionText = String(payload.text || strings.t("meaning.empty")).trim().slice(0, 4000)
    meaningFlick.contentY = 0
  }

  function fetchThesaurus(word) {
    if (!word) {
      root.thesaurus = []
      root.thesaurusMessage = ""
      return
    }
    root.thesaurusSerial += 1
    var serial = root.thesaurusSerial
    root.thesaurusRunning = true
    root.thesaurusMessage = ""
    if (thesaurusProc.running) thesaurusProc.running = false
    root.attachStream(thesaurusOut, "thesaurus", serial, root.applyThesaurus)
    thesaurusProc.command = ["python3", root.searchScript, "--thesaurus", word]
    thesaurusProc.running = true
  }

  function applyThesaurus(text, serial) {
    if (serial !== root.thesaurusSerial || !root.opened) return
    root.thesaurusRunning = false
    var payload = ({})
    try { payload = JSON.parse(text || "{}") || ({}) } catch (error) { payload = ({ ok: false }) }
    if (!payload.ok) {
      root.thesaurus = []
      root.thesaurusMessage = String(payload.error || strings.t("thesaurus.unavailable")).slice(0, 160)
      return
    }
    root.thesaurus = payload.results || []
    root.thesaurusMessage = root.thesaurus.length === 0 ? strings.t("thesaurus.empty") : ""
    var found = root.findIndex(root.thesaurus, root.pendingThesaurus)
    root.thesaurusIndex = found >= 0 ? found : 0
    if (found >= 0) root.fetchDefinition(root.pendingThesaurus)
    if (root.thesaurus.length > 0) {
      Qt.callLater(function() {
        if (thesaurusList.count > root.thesaurusIndex)
          thesaurusList.positionViewAtIndex(root.thesaurusIndex, ListView.Contain)
      })
    }
  }

  function chooseWord(index) {
    if (index < 0 || index >= root.matches.length) return
    root.selectedIndex = index
    root.thesaurusActive = false
    root.pendingWord = root.selectedWord()
    root.pendingThesaurus = ""
    root.showZone("words")
    root.fetchDefinition(root.pendingWord)
    root.fetchThesaurus(root.pendingWord)
  }

  function chooseThesaurus(index) {
    if (index < 0 || index >= root.thesaurus.length) return
    root.thesaurusIndex = index
    root.thesaurusActive = true
    root.pendingThesaurus = root.currentThesaurusWord()
    root.showZone("thesaurus")
    root.fetchDefinition(root.pendingThesaurus)
  }

  Process {
    id: searchProc
    running: false
    stdout: StdioCollector { id: searchOut; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
  }

  Process {
    id: definitionProc
    running: false
    stdout: StdioCollector { id: definitionOut; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
  }

  Process {
    id: thesaurusProc
    running: false
    stdout: StdioCollector { id: thesaurusOut; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
  }

  Shortcut {
    sequences: ["Ctrl+Left", "Ctrl+Right"]
    enabled: root.opened && root.focusZone !== "pattern"
    onActivated: root.setDescending(!root.descending)
  }
  Shortcut {
    sequence: "Ctrl+Up"
    enabled: root.opened && root.focusZone !== "pattern"
    onActivated: root.cycleHistory("up")
  }
  Shortcut {
    sequence: "Ctrl+Down"
    enabled: root.opened && root.focusZone !== "pattern"
    onActivated: root.cycleHistory("down")
  }
  Shortcut {
    sequence: "Ctrl+Backspace"
    enabled: root.opened && root.focusZone !== "pattern"
    onActivated: root.resetSearch()
  }
  Shortcut {
    sequence: "Ctrl+D"
    enabled: root.opened && root.focusZone !== "pattern"
    onActivated: root.showZone("pattern")
  }
  Shortcut {
    sequence: "Ctrl+T"
    enabled: root.opened && root.focusZone !== "pattern"
    onActivated: root.showZone("thesaurus")
  }
  Shortcut {
    sequence: "Ctrl+C"
    enabled: root.opened && root.focusZone !== "pattern"
    onActivated: root.copyFocused(false)
  }
  Shortcut {
    sequence: "Escape"
    enabled: root.opened && root.focusZone !== "pattern"
    onActivated: root.dismiss()
  }

  component ClickSurface: Item {
    id: chip

    default property alias content: content.data
    property alias color: surface.color
    property alias borderSpec: surface.borderSpec
    property alias radius: surface.radius
    signal activated()

    BorderSurface {
      id: surface
      anchors.fill: parent
      enabled: false
    }

    Item {
      id: content
      z: 1
      anchors.fill: parent
    }

    MouseArea {
      z: 10
      anchors.fill: parent
      preventStealing: true
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onPressed: function(mouse) {
        mouse.accepted = true
        chip.activated()
      }
    }
  }

  OverlayWindow {
    id: panel
    shown: root.opened

    Shortcut {
      sequences: [StandardKey.ZoomIn, "Ctrl+=", "Ctrl++", "Ctrl+Shift+="]
      enabled: root.opened
      context: Qt.WindowShortcut
      onActivated: root.stepScale(1)
    }
    Shortcut {
      sequences: [StandardKey.ZoomOut, "Ctrl+-", "Ctrl+_"]
      enabled: root.opened
      context: Qt.WindowShortcut
      onActivated: root.stepScale(-1)
    }
    Shortcut {
      sequence: "Ctrl+0"
      enabled: root.opened
      context: Qt.WindowShortcut
      onActivated: root.resetScale()
    }
    WlrLayershell.namespace: "omarchy-lexicon"
    onContentRevealedChanged: if (contentRevealed && root.opened && root.focusZone === "pattern") filterInput.forceActiveFocus()

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

      MouseArea {
        z: -1
        anchors.fill: parent
        onClicked: {}
      }

      Item {
        id: keyCatcher
        z: 2
        anchors.fill: parent
        Keys.priority: Keys.BeforeItem
        Keys.onShortcutOverride: function(event) { if (root.zoomDirection(event)) event.accepted = true }
        Keys.onPressed: function(event) { root.handleNavKey(event) }

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

            BorderSurface {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - statusLabel.width - parent.spacing
              height: parent.height
              radius: root.cornerRadius
              color: Style.controlFill(root.focusZone === "pattern", false, root.foreground, root.accent)
              borderSpec: Border.controlSpec(root.focusZone === "pattern" ? "focus" : "normal", root.foreground, root.accent)

              TextInput {
                id: filterInput
                anchors.fill: parent
                anchors.margins: Style.space(8)
                focus: true
                clip: true
                selectByMouse: true
                verticalAlignment: TextInput.AlignVCenter
                color: root.foreground
                selectionColor: root.selectedBackground
                selectedTextColor: root.selectedText
                font.family: root.fontFamily
                font.pixelSize: root.textHeading
                Keys.priority: Keys.BeforeItem
                Keys.forwardTo: [keyCatcher]
                Keys.onPressed: function(event) {
                  if (event.modifiers & (Qt.AltModifier | Qt.MetaModifier)) event.accepted = true
                }
                onActiveFocusChanged: if (activeFocus && root.focusZone !== "pattern") root.focusZone = "pattern"
                onTextChanged: if (!root.suppressFilter && text !== root.filterText) root.setPattern(text)

                cursorDelegate: Rectangle {
                  id: caret
                  width: Math.max(2, root.dp(2))
                  color: root.accent
                  visible: filterInput.activeFocus && root.focusZone === "pattern"
                  property bool blinkOn: true
                  opacity: blinkOn ? 1 : 0

                  Connections {
                    target: filterInput
                    function onCursorPositionChanged() {
                      caret.blinkOn = true
                      caretTimer.restart()
                    }
                    function onTextChanged() {
                      caret.blinkOn = true
                      caretTimer.restart()
                    }
                  }

                  Timer {
                    id: caretTimer
                    interval: 530
                    running: caret.visible
                    repeat: true
                    onTriggered: caret.blinkOn = !caret.blinkOn
                  }
                }
              }

              Text {
                textFormat: Text.PlainText
                anchors.fill: filterInput
                anchors.leftMargin: Style.space(2)
                verticalAlignment: Text.AlignVCenter
                visible: !root.filterText && !filterInput.preeditText
                text: strings.t("search.hint")
                color: root.foreground
                opacity: 0.58
                font.family: root.fontFamily
                font.pixelSize: root.textHeading
                elide: Text.ElideRight
              }
            }

            Text {
              id: statusLabel
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(Style.space(220), parent.width * 0.28)
              horizontalAlignment: Text.AlignRight
              text: root.searchRunning ? strings.t("search.running") : root.statusMessage
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: root.textCaption
              elide: Text.ElideRight
            }
          }

          Text {
            width: parent.width
            height: root.hintHeight
            textFormat: Text.PlainText
            text: strings.t("hint.line")
            color: root.foreground
            opacity: 0.62
            font.family: root.fontFamily
            font.pixelSize: root.textCaption
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
          }

          Row {
            z: 10
            width: parent.width
            height: root.optionHeight
            spacing: root.dp(Style.space(8))

            ClickSurface {
              width: (parent.width - parent.spacing * 4 - root.sizeSlot) / 4
              height: parent.height
              radius: root.cornerRadius
              color: Style.controlFill(root.focusZone === "length", false, root.foreground, root.accent)
              borderSpec: Border.controlSpec(root.focusZone === "length" ? "focus" : "normal", root.foreground, root.accent)
              onActivated: root.showZone("length")

              Item {
                id: lengthFocus
                anchors.fill: parent
                activeFocusOnTab: true
                Keys.onPressed: function(event) { root.handleNavKey(event) }
              }

              Row {
                anchors.centerIn: parent
                spacing: Style.space(8)
                Text {
                  textFormat: Text.PlainText
                  text: strings.t("option.length")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: root.textBody
                }
                Text {
                  textFormat: Text.PlainText
                  text: root.lengthValue > 0 ? String(root.lengthValue) : strings.t("option.any")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: root.textBody
                  font.bold: true
                }
              }
            }

            ClickSurface {
              width: (parent.width - parent.spacing * 4 - root.sizeSlot) / 4
              height: parent.height
              radius: root.cornerRadius
              color: Style.controlFill(root.focusZone === "rack", false, root.foreground, root.accent)
              borderSpec: Border.controlSpec(root.focusZone === "rack" ? "focus" : "normal", root.foreground, root.accent)
              onActivated: {
                root.showZone("rack")
                root.setRack(!root.rackOn)
              }

              Item {
                id: rackFocus
                anchors.fill: parent
                activeFocusOnTab: true
                Keys.onPressed: function(event) { root.handleNavKey(event) }
              }

              Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                spacing: Style.space(8)
                Text {
                  textFormat: Text.PlainText
                  anchors.verticalCenter: parent.verticalCenter
                  text: strings.t("option.rack")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: root.textBody
                }
                Text {
                  textFormat: Text.PlainText
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.rackOn ? strings.t("option.on") : strings.t("option.off")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: root.textBody
                  font.bold: root.rackOn
                }
                ToggleSwitch {
                  checked: root.rackOn
                  interactive: false
                  hasCursor: root.focusZone === "rack"
                }
              }
            }

            ClickSurface {
              width: (parent.width - parent.spacing * 4 - root.sizeSlot) / 4
              height: parent.height
              radius: root.cornerRadius
              color: Style.controlFill(root.focusZone === "letters", false, root.foreground, root.accent)
              borderSpec: Border.controlSpec(root.focusZone === "letters" ? "focus" : "normal", root.foreground, root.accent)
              onActivated: {
                root.showZone("letters")
                root.setByLetters(!root.byLetters)
              }

              Item {
                id: lettersFocus
                anchors.fill: parent
                activeFocusOnTab: true
                Keys.onPressed: function(event) { root.handleNavKey(event) }
              }

              Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                spacing: Style.space(8)
                Text {
                  textFormat: Text.PlainText
                  anchors.verticalCenter: parent.verticalCenter
                  text: strings.t("option.letters")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: root.textBody
                }
                Text {
                  textFormat: Text.PlainText
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.byLetters ? strings.t("option.on") : strings.t("option.off")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: root.textBody
                  font.bold: root.byLetters
                }
                ToggleSwitch {
                  checked: root.byLetters
                  interactive: false
                  hasCursor: root.focusZone === "letters"
                }
              }
            }

            ClickSurface {
              width: (parent.width - parent.spacing * 4 - root.sizeSlot) / 4
              height: parent.height
              radius: root.cornerRadius
              color: Style.controlFill(root.focusZone === "sort", false, root.foreground, root.accent)
              borderSpec: Border.controlSpec(root.focusZone === "sort" ? "focus" : "normal", root.foreground, root.accent)
              onActivated: {
                root.showZone("sort")
                root.setDescending(!root.descending)
              }

              Item {
                id: sortFocus
                anchors.fill: parent
                activeFocusOnTab: true
                Keys.onPressed: function(event) { root.handleNavKey(event) }
              }

              Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                spacing: Style.space(8)
                Text {
                  textFormat: Text.PlainText
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.descending ? strings.t("option.descending") : strings.t("option.ascending")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: root.textBody
                }
                ToggleSwitch {
                  checked: root.descending
                  interactive: false
                  hasCursor: root.focusZone === "sort"
                }
              }
            }

            Row {
              width: root.sizeSlot
              height: parent.height
              spacing: Style.space(6)

              ClickSurface {
                width: parent.height
                height: parent.height
                radius: root.cornerRadius
                color: Style.controlFill(false, false, root.foreground, root.accent)
                borderSpec: Border.controlSpec("normal", root.foreground, root.accent)
                onActivated: root.stepScale(-1)
                Text {
                  anchors.centerIn: parent
                  text: "−"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: root.textTitle
                  font.bold: true
                }
              }

              Text {
                width: parent.width - parent.height * 2 - parent.spacing * 2
                height: parent.height
                textFormat: Text.PlainText
                text: Math.round(root.uiScale * 100) + "%"
                color: root.foreground
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: root.fontFamily
                font.pixelSize: root.textBody
                font.bold: true
              }

              ClickSurface {
                width: parent.height
                height: parent.height
                radius: root.cornerRadius
                color: Style.controlFill(false, false, root.foreground, root.accent)
                borderSpec: Border.controlSpec("normal", root.foreground, root.accent)
                onActivated: root.stepScale(1)
                Text {
                  anchors.centerIn: parent
                  text: "+"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: root.textTitle
                  font.bold: true
                }
              }
            }
          }

          Row {
            id: fontRow
            z: 10
            width: parent.width
            height: root.optionHeight
            spacing: root.dp(Style.space(8))

            Repeater {
              model: root.fontOptions
              delegate: Item {
                required property int index
                required property string modelData
                width: (fontRow.width - fontRow.spacing * 4) / 5
                height: fontRow.height

                ClickSurface {
                  anchors.fill: parent
                  radius: root.cornerRadius
                  color: Style.controlFill(modelData === root.fontId, false, root.foreground, root.accent)
                  borderSpec: Border.controlSpec(modelData === root.fontId ? "focus" : "normal", root.foreground, root.accent)
                  onActivated: root.chooseFont(modelData)

                  Text {
                    anchors.centerIn: parent
                    width: parent.width - Style.space(8)
                    textFormat: Text.PlainText
                    text: root.fontChoiceLabel(modelData)
                    color: root.foreground
                    horizontalAlignment: Text.AlignHCenter
                    font.family: root.fontChoiceFamily(modelData)
                    font.pixelSize: root.textTitle
                    font.bold: modelData === root.fontId
                    elide: Text.ElideRight
                  }
                }
              }
            }
          }

          Row {
            z: 0
            clip: true
            width: parent.width
            height: Math.max(0, parent.height - root.headerHeight - root.hintHeight - root.optionHeight * 2 - root.contentSpacing * 4)
            spacing: Style.space(12)

            Column {
              width: (parent.width - parent.spacing * 2) / 3
              height: parent.height
              spacing: Style.space(4)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: strings.t("column.words")
                color: root.foreground
                opacity: root.focusZone === "words" ? 1 : 0.6
                font.family: root.fontFamily
                font.pixelSize: root.textCaption
                font.bold: root.focusZone === "words"
              }

              ListView {
                id: resultList
                width: parent.width
                height: parent.height - root.textCaption - parent.spacing
                model: root.matches
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                activeFocusOnTab: true
                keyNavigationEnabled: false
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) { root.handleNavKey(event) }

                delegate: Rectangle {
                  required property int index
                  required property string modelData
                  readonly property bool chosen: index === root.selectedIndex
                  width: ListView.view.width
                  height: root.rowHeight
                  radius: root.cornerRadius
                  color: chosen ? root.selectedBackground : "transparent"

                  Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    x: Style.space(10)
                    width: parent.width - Style.space(20)
                    text: parent.modelData
                    color: parent.chosen ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: root.textTitle
                    elide: Text.ElideRight
                  }

                  MouseArea {
                    z: 10
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onPressed: function(mouse) {
                      mouse.accepted = true
                      root.chooseWord(index)
                    }
                  }
                }

                Text {
                  anchors.centerIn: parent
                  width: parent.width
                  visible: root.matches.length === 0 && !root.searchRunning && root.filterText.length > 0
                  textFormat: Text.PlainText
                  text: strings.t("results.none").arg(root.filterText)
                  color: root.foreground
                  opacity: 0.6
                  font.family: root.fontFamily
                  font.pixelSize: root.textBody
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }
              }
            }

            Column {
              width: (parent.width - parent.spacing * 2) / 3
              height: parent.height
              spacing: Style.space(4)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: strings.t("column.meaning")
                color: root.foreground
                opacity: root.focusZone === "meaning" ? 1 : 0.6
                font.family: root.fontFamily
                font.pixelSize: root.textCaption
                font.bold: root.focusZone === "meaning"
              }

              Flickable {
                id: meaningFlick
                width: parent.width
                height: parent.height - root.textCaption - parent.spacing
                contentWidth: width
                contentHeight: meaningText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                activeFocusOnTab: true
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) { root.handleNavKey(event) }

                Text {
                  id: meaningText
                  z: 1
                  width: meaningFlick.width
                  textFormat: Text.PlainText
                  text: root.definitionText || strings.t("meaning.empty")
                  color: root.foreground
                  opacity: root.definitionText ? 0.9 : 0.55
                  font.family: root.fontFamily
                  font.pixelSize: root.textBody
                  wrapMode: Text.WordWrap
                }

                MouseArea {
                  z: -1
                  anchors.fill: parent
                  onPressed: function(mouse) {
                    mouse.accepted = true
                    root.showZone("meaning")
                  }
                }
              }
            }

            Column {
              width: (parent.width - parent.spacing * 2) / 3
              height: parent.height
              spacing: Style.space(4)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: strings.t("column.thesaurus")
                color: root.foreground
                opacity: root.focusZone === "thesaurus" ? 1 : 0.6
                font.family: root.fontFamily
                font.pixelSize: root.textCaption
                font.bold: root.focusZone === "thesaurus"
              }

              ListView {
                id: thesaurusList
                width: parent.width
                height: parent.height - root.textCaption - parent.spacing
                model: root.thesaurus
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                activeFocusOnTab: true
                keyNavigationEnabled: false
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) { root.handleNavKey(event) }

                delegate: Rectangle {
                  required property int index
                  required property string modelData
                  readonly property bool chosen: index === root.thesaurusIndex && root.thesaurus.length > 0
                  width: ListView.view.width
                  height: root.rowHeight
                  radius: root.cornerRadius
                  color: chosen && root.thesaurusActive ? root.selectedBackground : "transparent"

                  Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    x: Style.space(10)
                    width: parent.width - Style.space(20)
                    text: parent.modelData
                    color: parent.chosen && root.thesaurusActive ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: root.textBody
                    elide: Text.ElideRight
                  }

                  MouseArea {
                    z: 10
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onPressed: function(mouse) {
                      mouse.accepted = true
                      root.chooseThesaurus(index)
                    }
                  }
                }

                Text {
                  anchors.centerIn: parent
                  width: parent.width - Style.space(12)
                  visible: root.thesaurusMessage.length > 0 && root.thesaurus.length === 0
                  textFormat: Text.PlainText
                  text: root.thesaurusMessage
                  color: root.foreground
                  opacity: 0.6
                  font.family: root.fontFamily
                  font.pixelSize: root.textBody
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }
              }
            }
          }
        }
      }
    }
  }
}
