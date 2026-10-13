.pragma library

var PLUGIN_ID = "bar-glow"

var DEFAULTS = {
  enabled: true,
  size: 18,
  opacity: 0.72,
  color: "#000000",
  forceWhite: true,
  contentColor: "#ffffff",
  followTheme: false,
  followWallpaper: false,
  autoContrast: false,
  nightLight: false,
  tintChip: false
}

var MAX_PRESETS = 8

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

// shell.json is `{ bar: { layout } }`. The plugin shell publishes `barConfig`,
// which is the bar object itself (`{ layout }`). Accept both.
function layoutOf(config) {
  if (!isPlainObject(config)) return null
  if (isPlainObject(config.bar) && isPlainObject(config.bar.layout)) return config.bar.layout
  if (isPlainObject(config.layout)) return config.layout
  return null
}

function findEntry(config, id) {
  var fromBar = null
  var fromPlugins = null
  var layout = layoutOf(config)
  if (layout) {
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var arr = layout[sections[s]]
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
  var layout = layoutOf(config)
  if (layout) {
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var arr = layout[sections[s]]
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

function colorText(value, fallback) {
  var text = normalizeHex(value)
  if (text === "theme" || (text && text.charAt(0) === "#")) return text
  return fallback
}

function relativeLuminance(r, g, b) {
  function linear(channel) {
    var s = channel > 1 ? channel / 255 : channel
    return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4)
  }
  return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
}

function luminanceOfHex(value) {
  var rgb = parseHexRgb(value)
  if (!rgb) return 0
  return relativeLuminance(rgb.r, rgb.g, rgb.b)
}

function contrastInkFromLuma(luma) {
  return Number(luma) > 0.55 ? "#141414" : "#f4f4f4"
}

function contrastInk(value) {
  return contrastInkFromLuma(luminanceOfHex(value))
}

function effectiveOpacity(opacity, luma, enabled, haveSample) {
  var base = opacityValue(opacity, DEFAULTS.opacity)
  if (!enabled || !haveSample) return base
  if (Number(luma) > 0.62) return Math.max(base, 0.88)
  return base
}

function kelvinToRgb(kelvin) {
  var temp = clamp(kelvin, 1000, 40000) / 100
  var r
  var g
  var b
  if (temp <= 66) {
    r = 255
    g = 99.4708025861 * Math.log(temp) - 161.1195681661
    b = temp <= 19 ? 0 : 138.5177312231 * Math.log(temp - 10) - 305.0447927307
  } else {
    r = 329.698727446 * Math.pow(temp - 60, -0.1332047592)
    g = 288.1221695283 * Math.pow(temp - 60, -0.0755148492)
    b = 255
  }
  return {
    r: clamp(r, 0, 255) / 255,
    g: clamp(g, 0, 255) / 255,
    b: clamp(b, 0, 255) / 255
  }
}

// Multiply the glow by a warm gel. 6500K and above, and unknown readings, leave it alone.
function applyKelvin(value, kelvin) {
  var hex = colorText(value, "#000000")
  if (hex === "theme") hex = "#000000"
  var k = Number(kelvin)
  if (!isFinite(k) || k <= 0 || k >= 6000) return hex
  var src = parseHexRgb(hex) || { r: 0, g: 0, b: 0 }
  var gel = kelvinToRgb(k)
  var strength = clamp((6000 - k) / 2500, 0, 1)
  return colorToHex({
    r: src.r * ((1 - strength) + gel.r * strength),
    g: src.g * ((1 - strength) + gel.g * strength),
    b: src.b * ((1 - strength) + gel.b * strength)
  })
}

// Wallpaper is drawn with PreserveAspectCrop: scale to cover, crop the center.
function cropRect(imgW, imgH, screenW, screenH, edge, barPx) {
  var iw = Math.round(Number(imgW))
  var ih = Math.round(Number(imgH))
  var sw = Math.round(Number(screenW))
  var sh = Math.round(Number(screenH))
  var bar = Math.round(Number(barPx))
  if (iw < 2 || ih < 2 || sw < 2 || sh < 2 || bar < 1) return null
  if (iw * ih > 40000000) return null
  var scale = Math.max(sw / iw, sh / ih)
  if (!isFinite(scale) || scale <= 0) return null
  var offX = (iw * scale - sw) / 2
  var offY = (ih * scale - sh) / 2
  var sx = offX
  var sy = offY
  var cw = sw
  var ch = bar
  if (edge === "bottom") sy = offY + sh - bar
  else if (edge === "left") { cw = bar; ch = sh }
  else if (edge === "right") { sx = offX + sw - bar; cw = bar; ch = sh }
  var x = Math.max(0, Math.floor(sx / scale))
  var y = Math.max(0, Math.floor(sy / scale))
  var w = Math.max(1, Math.min(iw - x, Math.ceil(cw / scale)))
  var h = Math.max(1, Math.min(ih - y, Math.ceil(ch / scale)))
  if (w < 1 || h < 1 || x >= iw || y >= ih) return null
  return { x: x, y: y, w: w, h: h }
}

function cleanPresetName(value) {
  var name = String(value || "").replace(/[\u0000-\u001f]/g, "").replace(/^\s+|\s+$/g, "")
  if (!name) return ""
  if (name.length > 32) name = name.substring(0, 32).replace(/\s+$/g, "")
  return name
}

function sanitizePresets(value) {
  var list = value
  if (typeof list === "string") {
    try { list = JSON.parse(list) } catch (e) { list = [] }
  }
  if (!Array.isArray(list)) return []
  var out = []
  var seen = {}
  for (var i = 0; i < list.length && out.length < MAX_PRESETS; i++) {
    var item = list[i]
    if (!isPlainObject(item)) continue
    var name = cleanPresetName(item.name)
    if (!name || seen[name]) continue
    seen[name] = true
    out.push({
      name: name,
      size: sizeValue(item.size, DEFAULTS.size),
      opacity: opacityValue(item.opacity, DEFAULTS.opacity),
      color: colorText(item.color, DEFAULTS.color),
      contentColor: colorText(item.contentColor, DEFAULTS.contentColor),
      forceWhite: boolValue(item.forceWhite, true),
      followTheme: boolValue(item.followTheme, false),
      followWallpaper: boolValue(item.followWallpaper, false),
      autoContrast: boolValue(item.autoContrast, false),
      nightLight: boolValue(item.nightLight, false),
      tintChip: boolValue(item.tintChip, false)
    })
  }
  return out
}

function capturePreset(live, name) {
  var src = isPlainObject(live) ? live : {}
  var cleaned = sanitizePresets([{
    name: name,
    size: src.size,
    opacity: src.opacity,
    color: src.followTheme ? "theme" : src.color,
    contentColor: src.followTheme ? "theme" : src.contentColor,
    forceWhite: src.forceWhite,
    followTheme: src.followTheme,
    followWallpaper: src.followWallpaper && !src.followTheme,
    autoContrast: src.autoContrast,
    nightLight: src.nightLight,
    tintChip: src.tintChip
  }])
  return cleaned.length ? cleaned[0] : null
}

function savePreset(list, preset) {
  var next = sanitizePresets(list).filter(function(item) { return item.name !== preset.name })
  next.push(preset)
  if (next.length > MAX_PRESETS) next = next.slice(next.length - MAX_PRESETS)
  return next
}

function removePreset(list, index) {
  var next = sanitizePresets(list)
  var at = Math.round(Number(index))
  if (at < 0 || at >= next.length) return next
  next.splice(at, 1)
  return next
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
    followTheme: boolValue(readKey(src, "followTheme", DEFAULTS.followTheme), DEFAULTS.followTheme),
    followWallpaper: boolValue(readKey(src, "followWallpaper", DEFAULTS.followWallpaper), DEFAULTS.followWallpaper),
    autoContrast: boolValue(readKey(src, "autoContrast", DEFAULTS.autoContrast), DEFAULTS.autoContrast),
    nightLight: boolValue(readKey(src, "nightLight", DEFAULTS.nightLight), DEFAULTS.nightLight),
    tintChip: boolValue(readKey(src, "tintChip", DEFAULTS.tintChip), DEFAULTS.tintChip),
    customPresets: sanitizePresets(readKey(src, "customPresets", []))
  }
}
