.pragma library

function defaultSession() {
  return {
    pattern: "",
    length: 0,
    rack: false,
    descending: false,
    selectedWord: "",
    thesaurusWord: ""
  }
}

function clampLength(value) {
  var number = parseInt(value, 10)
  if (isNaN(number) || number < 0) return 0
  if (number > 32) return 32
  return number
}

function cloneSession(session) {
  var source = session || {}
  return {
    pattern: String(source.pattern || "").trim().slice(0, 80),
    length: clampLength(source.length),
    rack: source.rack === true,
    descending: source.descending === true,
    selectedWord: String(source.selectedWord || "").slice(0, 80),
    thesaurusWord: String(source.thesaurusWord || "").slice(0, 80)
  }
}

function sessionsEqual(left, right) {
  return left.pattern === right.pattern
    && left.length === right.length
    && left.rack === right.rack
    && left.descending === right.descending
}

function rackLetters(pattern) {
  return String(pattern || "").toLowerCase().replace(/[^a-z]/g, "")
}

function rememberOnExit(history, session) {
  var next = cloneSession(session)
  var ring = []
  var incoming = history || []
  for (var index = 0; index < incoming.length; index++) ring.push(cloneSession(incoming[index]))
  if (next.pattern.trim().length > 0) {
    if (ring.length && sessionsEqual(ring[ring.length - 1], next)) ring[ring.length - 1] = next
    else {
      ring.push(next)
      if (ring.length > 3) ring = ring.slice(ring.length - 3)
    }
  }
  var cursor = -1
  if (next.pattern.trim().length > 0 && ring.length && sessionsEqual(ring[ring.length - 1], next))
    cursor = ring.length - 1
  return { history: ring, current: next, cursor: cursor }
}

function moveHistory(history, cursor, direction) {
  var ring = history || []
  var index = typeof cursor === "number" ? cursor : -1
  if (direction === "down") {
    if (index >= 0 && index < ring.length - 1) {
      index += 1
      return { cursor: index, session: cloneSession(ring[index]) }
    }
    return { cursor: -1, session: defaultSession() }
  }
  if (index < 0) {
    if (!ring.length) return { cursor: -1, session: defaultSession() }
    return { cursor: ring.length - 1, session: cloneSession(ring[ring.length - 1]) }
  }
  if (index > 0) {
    index -= 1
    return { cursor: index, session: cloneSession(ring[index]) }
  }
  if (!ring.length) return { cursor: -1, session: defaultSession() }
  return { cursor: 0, session: cloneSession(ring[0]) }
}

function normalizeState(raw) {
  var data = raw && typeof raw === "object" ? raw : {}
  var history = []
  var incoming = data.history || []
  for (var index = 0; index < incoming.length && history.length < 3; index++)
    history.push(cloneSession(incoming[index]))
  var current = cloneSession(data.current || defaultSession())
  var cursor = -1
  if (typeof data.cursor === "number" && data.cursor >= -1 && data.cursor < history.length)
    cursor = data.cursor
  else if (current.pattern.trim().length > 0 && history.length && sessionsEqual(history[history.length - 1], current))
    cursor = history.length - 1
  return { history: history, current: current, cursor: cursor }
}
