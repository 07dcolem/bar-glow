.pragma library

// String edits for a line that is not a Qt text input. Callers render the
// result themselves. Nothing here reads the clipboard.

function clampIndex(text, index) {
  var n = text ? String(text).length : 0
  var i = index | 0
  if (i < 0) return 0
  if (i > n) return n
  return i
}

function usable(ch) {
  if (!ch || ch.length !== 1) return false
  var c = ch.charCodeAt(0)
  if (c < 32 || c === 127) return false
  if (c >= 128 && c <= 159) return false
  return true
}

function normalize(text, maximumLength) {
  var src = String(text || "")
  var cap = maximumLength > 0 ? maximumLength : 0
  var out = ""
  for (var i = 0; i < src.length && out.length < cap; i++) {
    if (usable(src.charAt(i))) out += src.charAt(i)
  }
  return out
}

function insert(text, cursor, anchor, incoming, maximumLength) {
  var base = String(text || "")
  var cap = maximumLength > 0 ? maximumLength : 0
  var a = clampIndex(base, Math.min(cursor, anchor))
  var b = clampIndex(base, Math.max(cursor, anchor))
  var room = cap - (base.length - (b - a))
  if (room < 0) room = 0
  var clean = ""
  var src = String(incoming || "")
  for (var i = 0; i < src.length && clean.length < room; i++) {
    var ch = src.charAt(i)
    if (usable(ch)) clean += ch
  }
  var next = base.slice(0, a) + clean + base.slice(b)
  var pos = a + clean.length
  return { text: next, cursor: pos, anchor: pos }
}

function backspace(text, cursor, anchor) {
  var base = String(text || "")
  var a = clampIndex(base, Math.min(cursor, anchor))
  var b = clampIndex(base, Math.max(cursor, anchor))
  if (a !== b) return insert(base, a, b, "", base.length)
  if (a === 0) return { text: base, cursor: 0, anchor: 0 }
  return { text: base.slice(0, a - 1) + base.slice(a), cursor: a - 1, anchor: a - 1 }
}

function deleteForward(text, cursor, anchor) {
  var base = String(text || "")
  var a = clampIndex(base, Math.min(cursor, anchor))
  var b = clampIndex(base, Math.max(cursor, anchor))
  if (a !== b) return insert(base, a, b, "", base.length)
  if (a >= base.length) return { text: base, cursor: a, anchor: a }
  return { text: base.slice(0, a) + base.slice(a + 1), cursor: a, anchor: a }
}

function move(text, cursor, anchor, delta, extend) {
  var base = String(text || "")
  var pos = clampIndex(base, cursor + delta)
  return { cursor: pos, anchor: extend ? clampIndex(base, anchor) : pos }
}

function home(text, anchor, extend) {
  return { cursor: 0, anchor: extend ? clampIndex(text, anchor) : 0 }
}

function end(text, anchor, extend) {
  var n = String(text || "").length
  return { cursor: n, anchor: extend ? clampIndex(text, anchor) : n }
}
