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
  property bool definitionMissing: false
  property string definitionClosest: ""
  property string thesaurusClosest: ""
  property string detailTab: "def"
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
  readonly property color surface: Util.alpha(root.foreground, 0.05)
  readonly property color lineColor: Style.normalBorderFor(root.foreground, root.accent)
  readonly property color hoverFill: Style.hoverFillFor(root.foreground, root.accent)
  readonly property color mutedText: Util.alpha(root.foreground, 0.68)
  readonly property int smallRadius: Math.max(0, Math.min(root.cornerRadius, root.dp(6)))
  readonly property int cornerRadius: Style.cornerRadius
  property string fontId: "theme"
  property real uiScale: 1
  property double scaleTick: 0
  property var fontOptions: ["theme", "Liberation Sans", "Liberation Serif", "Liberation Mono", "iA Writer Quattro S"]
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
  property int contentSpacing: Math.max(1, Math.round(Style.spacing.xxl * root.uiScale))
  property int barHeight: Math.max(Math.round(Style.space(34) * root.uiScale), root.textBody + Math.round(Style.space(14) * root.uiScale))
  property int footerHeight: Math.max(Math.round(Style.space(30) * root.uiScale), root.textCaption + Math.round(Style.space(14) * root.uiScale))
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
    if (zone === "meaning") root.detailTab = "def"
    else if (zone === "thesaurus") root.detailTab = "syn"
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

  function detailZone() {
    return root.detailTab === "syn" ? "thesaurus" : "meaning"
  }

  function arrowTarget(zone, key) {
    if (key === Qt.Key_Right) {
      if (zone === "pattern") return "length"
      if (zone === "length") return "rack"
      if (zone === "rack") return "letters"
      if (zone === "letters") return "sort"
      if (zone === "words") return root.detailZone()
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
      if (zone === "length" || zone === "rack") return "words"
      if (zone === "letters" || zone === "sort") return root.detailZone()
    }
    if (key === Qt.Key_Up) {
      if (zone === "length" || zone === "rack" || zone === "letters" || zone === "sort") return "pattern"
      if (zone === "words") return "length"
      if (zone === "meaning") return "letters"
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
        root.showZone("letters")
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
    root.revealThesaurus(root.thesaurusIndex)
  }

  function revealThesaurus(index) {
    var chip = thesaurusChips.itemAt(index)
    if (!chip) return
    var limit = Math.max(0, thesaurusList.contentHeight - thesaurusList.height)
    var y = thesaurusList.contentY
    if (chip.y < y) y = chip.y
    else if (chip.y + chip.height > y + thesaurusList.height) y = chip.y + chip.height - thesaurusList.height
    thesaurusList.contentY = Math.max(0, Math.min(y, limit))
  }

  function activeWord() {
    if (root.thesaurusActive && root.currentThesaurusWord()) return root.currentThesaurusWord()
    return root.selectedWord()
  }

  function copyFocused(closeAfter) {
    var text = ""
    if (root.focusZone === "thesaurus") text = root.currentThesaurusWord()
    else if (root.focusZone === "pattern" && !closeAfter) text = root.filterText
    else if (root.focusZone === "words") text = root.selectedWord()
    else if (root.focusZone === "meaning") text = root.activeWord()
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
    root.definitionMissing = false
    root.definitionClosest = ""
    root.thesaurus = []
    root.thesaurusMessage = ""
    root.thesaurusClosest = ""
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
    root.definitionMissing = false
    root.definitionClosest = ""
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
    root.definitionClosest = String(payload.closest || "").slice(0, 80)
    root.definitionMissing = payload.found === false
    root.definitionText = root.definitionMissing ? "" : String(payload.text || "").trim().slice(0, 4000)
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
    root.thesaurusClosest = ""
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
    root.thesaurusClosest = String(payload.closest || "").slice(0, 80)
    root.thesaurusMessage = root.thesaurus.length === 0 ? strings.t("thesaurus.empty") : ""
    var found = root.findIndex(root.thesaurus, root.pendingThesaurus)
    root.thesaurusIndex = found >= 0 ? found : 0
    if (found >= 0) root.fetchDefinition(root.pendingThesaurus)
    if (root.thesaurus.length > 0) {
      thesaurusList.contentY = 0
      Qt.callLater(function() { root.revealThesaurus(root.thesaurusIndex) })
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

  function chooseThesaurus(index, openMeaning) {
    if (index < 0 || index >= root.thesaurus.length) return
    root.thesaurusIndex = index
    root.thesaurusActive = true
    root.pendingThesaurus = root.currentThesaurusWord()
    root.showZone(openMeaning ? "meaning" : "thesaurus")
    if (openMeaning) root.fetchDefinition(root.pendingThesaurus)
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


  // Invisible keyboard focus target for a control-bar zone.
  component FocusSink: Item {
    width: 0
    height: 0
    activeFocusOnTab: true
    Keys.onPressed: function(event) { root.handleNavKey(event) }
  }

  // One button inside a segmented group; `on` is the pressed (solid accent) state.
  component SegButton: Rectangle {
    id: segButton
    property string label: ""
    property bool on: false
    property bool first: false
    property string family: root.fontFamily
    property int pixelSize: root.textBody
    property int minWidth: 0
    signal activated()

    width: Math.max(segButton.minWidth, segLabel.implicitWidth + root.dp(Style.space(22)))
    height: parent ? parent.height : root.barHeight
    color: segButton.on ? root.accent : (segMouse.containsMouse ? root.hoverFill : "transparent")

    Rectangle {
      visible: !segButton.first
      width: 1
      height: parent.height
      color: root.lineColor
    }

    Text {
      id: segLabel
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: segButton.label
      color: segButton.on ? root.background : root.foreground
      font.family: segButton.family
      font.pixelSize: segButton.pixelSize
      font.bold: segButton.on
    }

    MouseArea {
      id: segMouse
      anchors.fill: parent
      hoverEnabled: true
      preventStealing: true
      cursorShape: Qt.PointingHandCursor
      onPressed: function(mouse) {
        mouse.accepted = true
        segButton.activated()
      }
    }
  }

  // Bordered strip holding SegButtons; the border turns accent when its zone has focus.
  component SegGroup: Rectangle {
    id: group
    default property alias buttons: segRow.data
    property bool focused: false

    width: segRow.implicitWidth + group.border.width * 2
    radius: root.smallRadius
    color: "transparent"
    clip: true
    border.width: group.focused ? Math.max(2, root.dp(2)) : 1
    border.color: group.focused ? root.accent : root.lineColor

    Row {
      id: segRow
      x: group.border.width
      y: group.border.width
      height: group.height - group.border.width * 2
    }
  }

  // Meaning / Synonyms tab in the detail card.
  component TabButton: Rectangle {
    id: tab
    property string label: ""
    property bool selected: false
    signal activated()

    width: tabLabel.implicitWidth + root.dp(Style.space(24))
    height: parent ? parent.height : root.barHeight
    radius: root.smallRadius
    color: tabMouse.containsMouse && !tab.selected ? root.hoverFill : "transparent"
    border.width: 1
    border.color: tab.selected ? root.accent : root.lineColor

    Text {
      id: tabLabel
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: tab.label
      color: tab.selected ? root.accent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.textBody
      font.bold: tab.selected
    }

    MouseArea {
      id: tabMouse
      anchors.fill: parent
      hoverEnabled: true
      preventStealing: true
      cursorShape: Qt.PointingHandCursor
      onPressed: function(mouse) {
        mouse.accepted = true
        tab.activated()
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
          id: layout
          anchors.fill: parent
          anchors.topMargin: card.contentTopInset
          anchors.rightMargin: card.contentRightInset
          anchors.bottomMargin: card.contentBottomInset
          anchors.leftMargin: card.contentLeftInset
          spacing: root.contentSpacing

          // ── Search input + match count pill ──────────────────────────
          Item {
            width: parent.width
            height: root.headerHeight

            BorderSurface {
              anchors.left: parent.left
              anchors.right: countPill.visible ? countPill.left : parent.right
              anchors.rightMargin: countPill.visible ? root.dp(Style.space(12)) : 0
              height: parent.height
              radius: root.smallRadius
              color: root.surface
              borderSpec: Border.controlSpec(root.focusZone === "pattern" ? "focus" : "normal", root.foreground, root.accent)

              TextInput {
                id: filterInput
                anchors.fill: parent
                anchors.leftMargin: root.dp(Style.space(14))
                anchors.rightMargin: root.dp(Style.space(14))
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
                color: root.mutedText
                font.family: root.fontFamily
                font.pixelSize: root.textHeading
                elide: Text.ElideRight
              }
            }

            Rectangle {
              id: countPill
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              visible: countText.text.length > 0
              height: root.barHeight
              width: Math.min(countText.implicitWidth + root.dp(Style.space(32)), parent.width * 0.34)
              radius: height / 2
              color: root.surface
              border.width: 1
              border.color: root.lineColor

              Text {
                id: countText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - root.dp(Style.space(24)))
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                text: root.searchRunning ? strings.t("search.running") : root.statusMessage
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: root.textBody
                font.bold: true
                elide: Text.ElideRight
              }
            }
          }

          // ── Control bar: length · pattern/rack · sort key · direction · hint ─
          Item {
            z: 10
            width: parent.width
            height: root.barHeight

            Row {
              id: controls
              height: parent.height
              spacing: root.dp(Style.space(10))

              SegGroup {
                height: parent.height
                focused: root.focusZone === "length"

                FocusSink { id: lengthFocus }
                SegButton {
                  first: true
                  label: strings.t("option.any")
                  on: root.lengthValue === 0
                  onActivated: {
                    root.showZone("length")
                    root.setLength(0)
                  }
                }
                SegButton {
                  label: "−"
                  minWidth: parent.height
                  onActivated: {
                    root.showZone("length")
                    if (root.lengthValue > 0) root.setLength(root.lengthValue - 1)
                  }
                }
                SegButton {
                  label: root.lengthValue > 0
                    ? strings.tn("word.letters", root.lengthValue).arg(root.lengthValue)
                    : strings.t("option.length")
                  on: root.lengthValue > 0
                  onActivated: root.showZone("length")
                }
                SegButton {
                  label: "+"
                  minWidth: parent.height
                  onActivated: {
                    root.showZone("length")
                    root.setLength(root.lengthValue > 0 ? root.lengthValue + 1 : 3)
                  }
                }
              }

              SegGroup {
                height: parent.height
                focused: root.focusZone === "rack"

                FocusSink { id: rackFocus }
                SegButton {
                  first: true
                  label: strings.t("option.mode.pattern")
                  on: !root.rackOn
                  onActivated: {
                    root.showZone("rack")
                    if (root.rackOn) root.setRack(false)
                  }
                }
                SegButton {
                  label: strings.t("option.mode.rack")
                  on: root.rackOn
                  onActivated: {
                    root.showZone("rack")
                    if (!root.rackOn) root.setRack(true)
                  }
                }
              }

              SegGroup {
                height: parent.height
                focused: root.focusZone === "letters"

                FocusSink { id: lettersFocus }
                SegButton {
                  first: true
                  label: strings.t("option.sortby.alpha")
                  on: !root.byLetters
                  onActivated: {
                    root.showZone("letters")
                    if (root.byLetters) root.setByLetters(false)
                  }
                }
                SegButton {
                  label: strings.t("option.sortby.length")
                  on: root.byLetters
                  onActivated: {
                    root.showZone("letters")
                    if (!root.byLetters) root.setByLetters(true)
                  }
                }
              }

              SegGroup {
                height: parent.height
                focused: root.focusZone === "sort"

                FocusSink { id: sortFocus }
                SegButton {
                  first: true
                  label: root.byLetters
                    ? (root.descending ? strings.t("sort.length.desc") : strings.t("sort.length.asc"))
                    : (root.descending ? strings.t("sort.alpha.desc") : strings.t("sort.alpha.asc"))
                  onActivated: {
                    root.showZone("sort")
                    root.setDescending(!root.descending)
                  }
                }
              }
            }

            Text {
              anchors.left: controls.right
              anchors.leftMargin: root.dp(Style.space(14))
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              horizontalAlignment: Text.AlignRight
              text: strings.t("hint.wildcards")
              color: root.mutedText
              font.family: root.fontFamily
              font.pixelSize: root.textBody
              elide: Text.ElideLeft
            }
          }

          // ── Split view: word list | detail card ──────────────────────
          Item {
            id: split
            z: 0
            width: parent.width
            height: Math.max(0, parent.height - root.headerHeight - root.barHeight - root.footerHeight - root.contentSpacing * 3)
            readonly property int gap: root.dp(Style.space(14))

            ListView {
              id: resultList
              width: Math.round((split.width - split.gap) * 5 / 11)
              height: parent.height
              model: root.matches
              clip: true
              spacing: root.dp(2)
              boundsBehavior: Flickable.StopAtBounds
              activeFocusOnTab: true
              keyNavigationEnabled: false
              Keys.priority: Keys.BeforeItem
              Keys.onPressed: function(event) { root.handleNavKey(event) }

              delegate: Item {
                id: wordRow
                required property int index
                required property string modelData
                readonly property bool chosen: index === root.selectedIndex
                width: ListView.view.width
                height: root.rowHeight

                Rectangle {
                  anchors.fill: parent
                  radius: root.smallRadius
                  color: wordRow.chosen ? Util.alpha(root.accent, 0.12) : (rowMouse.containsMouse ? root.hoverFill : "transparent")
                  border.width: wordRow.chosen ? (root.focusZone === "words" ? Math.max(2, root.dp(2)) : 1) : 0
                  border.color: root.accent
                }

                Rectangle {
                  visible: wordRow.chosen
                  width: Math.max(3, root.dp(4))
                  height: parent.height
                  radius: root.smallRadius
                  color: root.accent
                }

                Text {
                  textFormat: Text.PlainText
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.leftMargin: root.dp(Style.space(16))
                  anchors.right: lengthTag.left
                  anchors.rightMargin: root.dp(Style.space(8))
                  text: wordRow.modelData
                  color: wordRow.chosen ? root.accent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: root.textTitle
                  font.bold: wordRow.chosen
                  elide: Text.ElideRight
                }

                Text {
                  id: lengthTag
                  textFormat: Text.PlainText
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.right: parent.right
                  anchors.rightMargin: root.dp(Style.space(12))
                  text: String(wordRow.modelData.length)
                  color: root.mutedText
                  font.family: root.fontFamily
                  font.pixelSize: root.textCaption
                }

                MouseArea {
                  id: rowMouse
                  z: 10
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  preventStealing: true
                  onPressed: function(mouse) {
                    mouse.accepted = true
                    root.chooseWord(wordRow.index)
                  }
                }
              }

              Text {
                anchors.centerIn: parent
                width: parent.width - root.dp(Style.space(24))
                visible: root.matches.length === 0 && !root.searchRunning && root.filterText.length > 0
                textFormat: Text.PlainText
                text: strings.t("results.empty")
                color: root.mutedText
                font.family: root.fontFamily
                font.pixelSize: root.textBody
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
              }
            }

            BorderSurface {
              id: detailCard
              x: resultList.width + split.gap
              width: split.width - x
              height: parent.height
              radius: root.smallRadius
              color: root.surface
              borderSpec: Border.controlSpec(root.focusZone === "meaning" || root.focusZone === "thesaurus" ? "focus" : "normal", root.foreground, root.accent)
              padding: root.dp(Style.space(16))

              Item {
                id: detailBody
                anchors.fill: parent
                anchors.topMargin: detailCard.contentTopInset
                anchors.rightMargin: detailCard.contentRightInset
                anchors.bottomMargin: detailCard.contentBottomInset
                anchors.leftMargin: detailCard.contentLeftInset

                Row {
                  id: detailTabs
                  height: root.barHeight
                  spacing: root.dp(Style.space(6))

                  TabButton {
                    label: strings.t("tab.meaning")
                    selected: root.detailTab === "def"
                    onActivated: root.showZone("meaning")
                  }
                  TabButton {
                    label: strings.t("tab.synonyms")
                    selected: root.detailTab === "syn"
                    onActivated: root.showZone("thesaurus")
                  }
                }

                Column {
                  id: detailHead
                  anchors.top: detailTabs.bottom
                  anchors.topMargin: root.dp(Style.space(14))
                  width: parent.width
                  spacing: root.dp(Style.space(4))
                  visible: root.activeWord().length > 0

                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: root.activeWord()
                    color: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Math.round(root.textHeading * 1.25)
                    font.bold: true
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: {
                      var word = root.activeWord()
                      var parts = [strings.tn("word.letters", word.length).arg(word.length)]
                      if (root.thesaurusActive && root.currentThesaurusWord())
                        parts.push(strings.t("detail.synonymOf").arg(root.selectedWord()))
                      return parts.join("  ·  ")
                    }
                    color: root.mutedText
                    font.family: root.fontFamily
                    font.pixelSize: root.textCaption
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    readonly property string closest: root.detailTab === "syn" ? root.thesaurusClosest : root.definitionClosest
                    visible: closest.length > 0
                    text: strings.t("detail.closest").arg(closest)
                    color: root.mutedText
                    font.family: root.fontFamily
                    font.pixelSize: root.textCaption
                    font.italic: true
                    elide: Text.ElideRight
                  }
                }

                Item {
                  id: detailContent
                  anchors.top: detailHead.visible ? detailHead.bottom : detailTabs.bottom
                  anchors.topMargin: root.dp(Style.space(12))
                  anchors.bottom: parent.bottom
                  width: parent.width

                  Flickable {
                    id: meaningFlick
                    anchors.fill: parent
                    visible: root.detailTab === "def"
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
                      readonly property bool hasBody: root.definitionText.length > 0 && !root.definitionMissing
                      text: {
                        if (root.definitionMissing) return strings.t("meaning.missing").arg(root.activeWord())
                        if (root.definitionText) return root.definitionText
                        return strings.t("meaning.empty")
                      }
                      color: hasBody ? root.foreground : root.mutedText
                      font.family: root.fontFamily
                      font.pixelSize: root.textBody
                      lineHeight: 1.2
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

                  Flickable {
                    id: thesaurusList
                    anchors.fill: parent
                    visible: root.detailTab === "syn"
                    contentWidth: width
                    contentHeight: chipFlow.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    activeFocusOnTab: true
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: function(event) { root.handleNavKey(event) }

                    Flow {
                      id: chipFlow
                      width: thesaurusList.width
                      spacing: root.dp(Style.space(6))

                      Repeater {
                        id: thesaurusChips
                        model: root.thesaurus

                        delegate: Rectangle {
                          id: chip
                          required property int index
                          required property string modelData
                          readonly property bool chosen: index === root.thesaurusIndex && root.thesaurusActive
                          width: Math.min(chipFlow.width, chipLabel.implicitWidth + root.dp(Style.space(20)))
                          height: Math.round(root.rowHeight * 0.85)
                          radius: root.smallRadius
                          color: chip.chosen ? root.accent : (chipMouse.containsMouse ? root.hoverFill : root.background)
                          border.width: 1
                          border.color: chip.chosen ? root.accent : root.lineColor

                          Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, chipFlow.width - root.dp(Style.space(20)))
                            textFormat: Text.PlainText
                            text: chip.modelData
                            color: chip.chosen ? root.background : root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: root.textBody
                            font.bold: chip.chosen
                            elide: Text.ElideRight
                          }

                          MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onPressed: function(mouse) {
                              mouse.accepted = true
                              root.chooseThesaurus(chip.index, true)
                            }
                          }
                        }
                      }
                    }

                    Text {
                      anchors.top: parent.top
                      width: parent.width
                      visible: root.thesaurus.length === 0
                      textFormat: Text.PlainText
                      text: root.thesaurusRunning
                        ? strings.t("meaning.looking")
                        : (root.thesaurusMessage || (root.selectedWord() ? "" : strings.t("meaning.empty")))
                      color: root.mutedText
                      font.family: root.fontFamily
                      font.pixelSize: root.textBody
                      wrapMode: Text.WordWrap
                    }

                    MouseArea {
                      z: -1
                      anchors.fill: parent
                      onPressed: function(mouse) {
                        mouse.accepted = true
                        root.showZone("thesaurus")
                      }
                    }
                  }
                }
              }
            }
          }

          // ── Footer: font · size · key hints ──────────────────────────
          Item {
            z: 10
            width: parent.width
            height: root.footerHeight

            Rectangle {
              y: -Math.round(root.contentSpacing / 2)
              width: parent.width
              height: 1
              color: root.lineColor
            }

            Row {
              id: footerRow
              anchors.verticalCenter: parent.verticalCenter
              height: parent.height - root.dp(Style.space(4))
              spacing: root.dp(Style.space(10))

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: strings.t("option.font").toUpperCase()
                color: root.mutedText
                font.family: root.fontFamily
                font.pixelSize: root.textCaption
                font.letterSpacing: root.textCaption * 0.08
              }

              SegGroup {
                height: parent.height

                Repeater {
                  model: root.fontOptions
                  delegate: SegButton {
                    required property int index
                    required property string modelData
                    first: index === 0
                    label: root.fontChoiceLabel(modelData)
                    family: root.fontChoiceFamily(modelData)
                    pixelSize: root.textCaption
                    on: modelData === root.fontId
                    onActivated: root.chooseFont(modelData)
                  }
                }
              }

              SegGroup {
                height: parent.height

                SegButton {
                  first: true
                  label: "−"
                  minWidth: parent.height
                  pixelSize: root.textCaption
                  onActivated: root.stepScale(-1)
                }
                SegButton {
                  label: Math.round(root.uiScale * 100) + "%"
                  pixelSize: root.textCaption
                  onActivated: root.resetScale()
                }
                SegButton {
                  label: "+"
                  minWidth: parent.height
                  pixelSize: root.textCaption
                  onActivated: root.stepScale(1)
                }
              }
            }

            Text {
              anchors.left: footerRow.right
              anchors.leftMargin: root.dp(Style.space(14))
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              horizontalAlignment: Text.AlignRight
              text: strings.t("footer.keys")
              color: root.mutedText
              font.family: root.fontFamily
              font.pixelSize: root.textCaption
              elide: Text.ElideLeft
            }
          }
        }
      }
    }
  }
}
