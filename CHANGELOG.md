# Changelog

## 1.1.3 — 2026-08-01

- Standardized About panel shared across the richardogcc utilities fleet.

## 1.1.2 — 2026-08-01

- Releases are now distributed as a DMG (`MScreenshot-<version>.dmg`) built by `scripts/release.sh` (previously a zip).
- Repo standardized to the shared macOS utilities convention: Swift tools 6.0, `VERSION`/`CHANGELOG.md` flow, and `app-manifest.json` for discovery by the MLauncher orchestrator.

## 1.1.1 — 2026-08-01

- **Fix: permission prompts on every update.** Builds were ad-hoc signed, so each update looked like a different app to macOS and Screen Recording permission was requested again. Builds are now signed with a stable identity — run `scripts/setup_signing.sh` once when building from source; permissions then survive updates.

## 1.1.0 — 2026-08-01

- **App fully in English** (UI, menus, settings, docs).
- **Automatic clipboard**: captures are copied to the clipboard as soon as they are taken (enabled by default, configurable).
- **In-place editing for selection captures**: a custom selection overlay (ScreenCaptureKit) opens the editor directly over the captured region with a floating toolbar — `Return` saves, `Esc` discards, and a button pops it out into the full editor window.
- **Configurable keyboard shortcuts**: record your own combinations in Settings, with a Restore Defaults option.
- The capture is now **centered** in the editor window.
- Minimum system version is now macOS 14.

## 1.0.0 — 2026-07-31

Initial release.

- Capture by selection, window or full screen (global shortcuts `⌃⇧3/4/5` and menu bar icon).
- Annotation editor: rectangular/circular/freeform blur, text with fonts and sizes, arrow, line, rectangle, ellipse, highlighter and numbered badges.
- Settings: destination folder, PNG/JPEG format, filename prefix, open editor after capture, copy to clipboard, sound, window shadow and launch at login.
- Undo/redo, zoom, save-as and copy to clipboard.
