.pragma library

var PLUGIN_ID = "bar-glow"

var DEFAULTS = {
  enabled: true,
  size: 18,
  opacity: 0.72,
  color: "#000000",
  forceWhite: true,
  contentColor: "#ffffff",
  followTheme: false
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function clamp(value, min, max) {
  var n = Number(value)
  if (!isFinite(n)) n = min
  return Math.max(min, Math.min(max, n))
}

function clamp01(value) {
  return clamp(value, 0, 1)
}

function hexChannel(channel) {
  var s = Math.round(clamp01(channel) * 255).toString(16)
  return s.length < 2 ? "0" + s : s
}

function colorToHex(color) {
  if (typeof color === "string") {
    var text = normalizeHex(color)
    return text || "#000000"
  }
  if (!color) return "#000000"
  return "#" + hexChannel(color.r) + hexChannel(color.g) + hexChannel(color.b)
}

function normalizeHex(value) {
  var text = String(value || "").replace(/^\s+|\s+$/g, "")
  if (text === "theme" || text === "auto") return text
  var shortHex = text.match(/^#([0-9A-Fa-f]{3})$/)
  if (shortHex) {
    var s = shortHex[1]
    return ("#" + s.charAt(0) + s.charAt(0) + s.charAt(1) + s.charAt(1)
      + s.charAt(2) + s.charAt(2)).toLowerCase()
  }
  var hex = text.match(/^#([0-9A-Fa-f]{6})([0-9A-Fa-f]{2})?$/)
  if (hex) return ("#" + hex[1]).toLowerCase()
  return ""
}

function parseHexRgb(value) {
  var hex = normalizeHex(value)
  if (!hex || hex.charAt(0) !== "#") return null
  return {
    r: parseInt(hex.substr(1, 2), 16) / 255,
    g: parseInt(hex.substr(3, 2), 16) / 255,
    b: parseInt(hex.substr(5, 2), 16) / 255
  }
}

function rgbToHsv(r, g, b) {
  var max = Math.max(r, g, b)
  var min = Math.min(r, g, b)
  var d = max - min
  var h = 0
  if (d > 0.00001) {
    if (max === r) h = ((g - b) / d) % 6
    else if (max === g) h = (b - r) / d + 2
    else h = (r - g) / d + 4
    h /= 6
    if (h < 0) h += 1
  }
  return { h: h, s: max === 0 ? 0 : d / max, v: max }
}

function hsvToRgb(h, s, v) {
  var hh = ((h % 1) + 1) % 1
  var i = Math.floor(hh * 6)
  var f = hh * 6 - i
  var p = v * (1 - s)
  var q = v * (1 - f * s)
  var t = v * (1 - (1 - f) * s)
  switch (i % 6) {
    case 0: return { r: v, g: t, b: p }
    case 1: return { r: q, g: v, b: p }
    case 2: return { r: p, g: v, b: t }
    case 3: return { r: p, g: q, b: v }
    case 4: return { r: t, g: p, b: v }
    default: return { r: v, g: p, b: q }
  }
}

function hexToHsv(value) {
  var rgb = parseHexRgb(value) || { r: 0, g: 0, b: 0 }
  return rgbToHsv(rgb.r, rgb.g, rgb.b)
}

function hsvToHex(h, s, v) {
  var rgb = hsvToRgb(h, s, v)
  return "#" + hexChannel(rgb.r) + hexChannel(rgb.g) + hexChannel(rgb.b)
}

function boolValue(value, fallback) {
  if (value === true || value === "true" || value === 1 || value === "1") return true
  if (value === false || value === "false" || value === 0 || value === "0") return false
  return fallback === true
}

function opacityValue(value, fallback) {
  var n = Number(value)
  if (!isFinite(n)) n = fallback
  if (n > 1) n = n / 100
  return clamp01(n)
}

function sizeValue(value, fallback) {
  return Math.round(clamp(value === undefined || value === null ? fallback : value, 0, 48))
}

function readKey(entry, name, fallback) {
  if (!isPlainObject(entry) || entry[name] === undefined || entry[name] === null) return fallback
  return entry[name]
}

function findEntry(config, id) {
  var fromBar = null
  var fromPlugins = null
  if (isPlainObject(config) && isPlainObject(config.bar) && isPlainObject(config.bar.layout)) {
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var arr = config.bar.layout[sections[s]]
      if (!Array.isArray(arr)) continue
      for (var i = 0; i < arr.length; i++) {
        if (arr[i] && String(arr[i].id) === id) fromBar = arr[i]
      }
    }
  }
  if (isPlainObject(config) && Array.isArray(config.plugins)) {
    for (var j = 0; j < config.plugins.length; j++) {
      if (config.plugins[j] && String(config.plugins[j].id) === id)
        fromPlugins = config.plugins[j]
    }
  }
  if (fromBar && fromPlugins) {
    var merged = {}
    for (var pk in fromPlugins) merged[pk] = fromPlugins[pk]
    for (var bk in fromBar) merged[bk] = fromBar[bk]
    return merged
  }
  return fromBar || fromPlugins || ({})
}

function writeEntries(config, id, values) {
  if (!isPlainObject(config) || !isPlainObject(values)) return
  function apply(entry) {
    if (!isPlainObject(entry)) return
    for (var key in values) {
      if (key === "id") continue
      entry[key] = values[key]
    }
  }
  // Prefer the bar layout. Omarchy's plugin remove only deletes the first
  // matching location (layout beats plugins[]), so writing both leaves a
  // stale plugins[] entry that blocks `plugin add --enable` on reinstall.
  var foundBar = false
  if (isPlainObject(config.bar) && isPlainObject(config.bar.layout)) {
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var arr = config.bar.layout[sections[s]]
      if (!Array.isArray(arr)) continue
      for (var i = 0; i < arr.length; i++) {
        if (arr[i] && String(arr[i].id) === id) {
          apply(arr[i])
          foundBar = true
        }
      }
    }
  }
  if (foundBar) return
  var foundPlugin = false
  if (Array.isArray(config.plugins)) {
    for (var j = 0; j < config.plugins.length; j++) {
      if (config.plugins[j] && String(config.plugins[j].id) === id) {
        apply(config.plugins[j])
        foundPlugin = true
      }
    }
  }
  if (!foundPlugin) {
    if (!Array.isArray(config.plugins)) config.plugins = []
    var entry = { id: id }
    apply(entry)
    config.plugins.push(entry)
  }
}

function snapshot(entry) {
  var src = isPlainObject(entry) ? entry : {}
  return {
    id: PLUGIN_ID,
    enabled: boolValue(readKey(src, "enabled", DEFAULTS.enabled), DEFAULTS.enabled),
    size: sizeValue(readKey(src, "size", DEFAULTS.size), DEFAULTS.size),
    opacity: opacityValue(readKey(src, "opacity", DEFAULTS.opacity), DEFAULTS.opacity),
    color: String(readKey(src, "color", DEFAULTS.color)),
    forceWhite: boolValue(readKey(src, "forceWhite", DEFAULTS.forceWhite), DEFAULTS.forceWhite),
    contentColor: String(readKey(src, "contentColor", DEFAULTS.contentColor)),
    followTheme: boolValue(readKey(src, "followTheme", DEFAULTS.followTheme), DEFAULTS.followTheme)
  }
}
