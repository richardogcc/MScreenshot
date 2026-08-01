# MScreenshot — project conventions

MScreenshot is a native macOS menu bar screenshot app (Swift Package Manager, AppKit). This file documents the conventions shared by all richardogcc macOS utility repos.

## Language and license

- Everything is in English: README, UI strings, code comments, commit messages.
- License: MIT, copyright line exactly `Copyright (c) 2026 richardogcc`.

## Identifiers

- Bundle ID scheme: `com.richardogcc.<lowercased-app-name>` — here `com.richardogcc.mscreenshot`.

## Toolchain

- `Package.swift` uses `// swift-tools-version: 6.0` with platforms `.macOS(.v14)`.
- This target keeps `swiftSettings: [.swiftLanguageMode(.v5)]` because Swift 6 strict concurrency would require a large refactor (shared singletons, non-Sendable captures). Prefer this over a big migration.

## Versioning

- `VERSION` at the repo root is the single source of truth (plain semver, e.g. `1.1.1`). The version is intentionally NOT duplicated in `app-manifest.json`.
- `CHANGELOG.md` follows the Keep a Changelog style; add an entry per release. Its per-version section is used as the GitHub release notes.

## Layout

- `Sources/MScreenshot/` — app sources.
- `Resources/` — `Info.plist` (version injected as `__VERSION__`) and `AppIcon.icns`. The app must always ship with an icon; regenerate it with `scripts/make_icon.swift` if missing.
- `scripts/` (lowercase):
  - `build_app.sh` — builds `build/MScreenshot.app` from a release swift build, injects the version from `VERSION` into `Info.plist`, copies `Resources/AppIcon.icns`, and signs the bundle.
  - `make_icon.swift` — regenerates the app icon.
  - `release.sh` — builds the app, packages `MScreenshot-<VERSION>.dmg` into `dist/` via `hdiutil`, then runs `gh release create`. Releases are always pushed manually from a local machine; automation must stop before the `gh release create` step.
  - `setup_signing.sh` / `install.sh` — repo-specific helpers (stable signing identity for TCC, local install).
- `app-manifest.json` — static metadata for a future orchestrator app to discover this utility (name, bundleId, description, repo, minMacOS, artifact pattern). No version field.

## Git rules for Claude

- Never push. Never create GitHub releases; a human runs `release.sh` locally.
- Commit messages in English, ending with the trailer:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- Never commit build artifacts (`.build/`, `build/`, `dist/`, `*.dmg`) or `.DS_Store`.
