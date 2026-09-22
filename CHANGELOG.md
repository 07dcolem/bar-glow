# Changelog

## 1.2.5

- Settings open without the bar icon. The plugin is also an `overlay`, so
  hiding the chip and leaving `bar-glow` enabled still opens the panel with
  `omarchy-shell shell toggle bar-glow` or `omarchy-shell bar-glow toggle`.
- Glyph color is owned by the glow service. Hiding the chip keeps the forced
  color, including theme-follow, and removing or disabling the plugin restores
  the previous bar text color.

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
