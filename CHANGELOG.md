# Changelog

## 1.3.1

- Preset names and hex codes are typed into a plain line that exists only
  while that row is open. The line does not read the clipboard. Paste is
  not available there; type the name or the hex code.

## 1.3.0

- Settings panel matches the quiet KeyboardPanel rhythm. Glow and glyph
  colors are compact rows (live swatch, hex, a few theme presets). The
  full saturation field opens in a nested card on that row. Escape or a
  click on the rest of the panel closes only the card.
- A faint background tint behind the controls follows the glow and glyph
  colors, and brightens briefly when a setting or color changes.
- Built-in looks: Subtle wash, Strong contrast, Accent only, and Theme
  only. Save current look stores up to eight named presets on the plugin
  entry. `x` removes the saved preset under the cursor.
- Sample under bar reads the wallpaper strip behind the bar (ImageMagick
  `identify`, then a crop) and sets the glow plus a contrasting glyph.
  Follow wallpaper, nested under that action, repeats the sample when the
  wallpaper changes.
- Auto contrast, night-light warmth, and bar-icon tint are off by default.
  Auto contrast and night light adjust the live glow without rewriting the
  saved hue. Theme changes crossfade the wash over 420ms.
- While the panel is open, `-` and `=` nudge opacity. Arrows move, Enter
  activates, Escape closes. Undo steps back through changes made since
  the panel opened. Ctrl+Z does the same. That history is not kept after
  the panel closes.

## 1.2.5

- Settings open without the bar icon. Matt Rich's overlay request in
  [#1](https://github.com/07dcolem/bar-glow/pull/1) shaped this update.
  The plugin is also an `overlay`, so hiding the chip and leaving
  `bar-glow` enabled still opens the panel with
  `omarchy-shell shell toggle bar-glow` or `omarchy-shell bar-glow toggle`.
  Those commands use the existing top-left fallback. Clicking the chip,
  when it is on the bar, still anchors the panel to the icon.
- With the chip on the bar, settings are still written only to that bar
  entry. With the chip hidden, they are written to the `plugins[]` entry.
  The service reads `shell.json`, so either place reaches the glow.
- Glyph color is owned by the glow service. Hiding the chip keeps the
  forced color, including theme-follow. The previous bar text color comes
  back when the glow is off, force-glyphs is off, or the plugin is removed
  or disabled.

## 1.2.4

- The on/off switch, theme-follow, and glyph toggle update the glow and bar
  glyphs on the click. Settings are read from the shell's published bar
  config and written with `updateEntryInline`.
- Glyph color overrides `bar.text` in the theme shell values, so the bar's
  own color binding stays intact. Assigning `Color.bar.text` had broken that
  binding until the shell was restarted.
- Panel open/close IPC goes through the plugin shell's `summon` / `hide` /
  `toggle`.
- Glow and glyph colors use a saturation/value field and a hue bar. Hex is
  still there for an exact value.

## 1.2.3

- Panel IPC (`toggle` / `open` / `close`) lives on the service so it is not
  stolen by a second `IpcHandler` on the same `bar-glow` target.
- Settings persist only to the bar layout when the chip is on the bar, so
  `omarchy plugin remove` does not leave a leftover `plugins[]` entry.

## 1.2.2

- Public packaging: author `07dcolem`, copyright Dylan Coleman, install URL,
  and an explicit no-warranty notice. Plugin behavior unchanged.

## 1.2.1

- Plugin id is `bar-glow` (no personal namespace). IPC target is `bar-glow`.

## 1.2.0

- Settings panel on the bar (Omarchy `KeyboardPanel`): opacity, bloom, glow
  color, glyph color, and a force-glyph toggle.
- **Use theme colors** button plus `followTheme`, so glow and glyphs track
  the active Omarchy theme.
- HSV + hex color pickers with presets.
- Service reads settings from `bar.layout` or `plugins[]`.

## 1.1.0

- Replaced the inner-edge drop shadow with a full-width glow behind the bar.
- Forced white glyphs so the glow stays readable on any wallpaper.

## 1.0.0

- Initial inner-edge drop shadow service.
