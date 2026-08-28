# Changelog

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
