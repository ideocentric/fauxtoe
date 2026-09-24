# Worklog

## 2026-09-24 13:37 — fauxto v1 built, licensed AGPL, localization-ready, pushed to private GitHub repo
**Completed:**
- Camera app implemented and confirmed working by the user: live preview, camera and resolution selection, rotation and mirroring, focus/exposure/white balance where supported, naming sheet, date-template and name-and-number (`root-001`) naming, save folder in the inspector, paged thumbnail strip (newest on the right, double-click opens, drag copies, missing files reported), interval shooting for stop motion.
- Quit path stops the capture session before exit (2 s cap), with steps logged under subsystem `com.ideocentric.fauxto`.
- Licensed AGPL-3.0-or-later: `LICENSE` (unmodified gnu.org text), SPDX headers in every Swift file, About box notice.
- README added, including a Translating section.
- Localization groundwork: `fauxto/Localizable.xcstrings` (all UI text, plural variants), `fauxto/InfoPlist.xcstrings`, `scripts/sync-strings.sh`. User checked the pseudo-languages visually and confirmed the text is correct.
- 16 unit tests pass (naming, numbering, rendering, encoding, localization).
- Private repo `ideocentric/fauxto` created; SSH remote `origin`; `main` pushed at `1f3da79`.

**In flight:** none.

**Open questions:**
- Root cause of the one quit hang on first run is unconfirmed; it has not recurred and was not reproduced. If it happens again, capture Xcode's stop reason and stack (debug navigator, or `bt all`), or run `log show --last 10m --predicate 'subsystem == "com.ideocentric.fauxto"'`.
- Copyright holder is "Matt Comeione" in all notices; ideocentric or "the fauxto contributors" were offered as alternatives and not decided.
- The template UI tests in `fauxtoUITests/` are unchanged and will trigger the camera permission prompt if run.
- Repo stays private until the icon graphics are done; making it public is a pending decision.

**Next step:** Add the app icon: place the icon PNGs (16, 32, 128, 256 and 512 pt at 1x and 2x) in `fauxto/Assets.xcassets/AppIcon.appiconset/` and list them in its `Contents.json`, build with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project fauxto.xcodeproj -scheme fauxto build`, commit, push, then ask whether to make `ideocentric/fauxto` public.
