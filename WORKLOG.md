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

## 2026-09-24 13:45 — Renamed fauxto to fauxtoe
**Completed:** Full rename: project, targets, scheme, folders (`fauxtoe/`, `fauxtoeTests/`, `fauxtoeUITests/`), Swift module, bundle IDs (`com.ideocentric.fauxtoe`), log subsystem, default save folder (`~/Pictures/fauxtoe`), default name template, UI strings and README. Entries above this one use the old name and paths.
**In flight:** GitHub repo rename (`ideocentric/fauxto` to `ideocentric/fauxtoe`), `origin` URL update, and moving the local checkout folder, pending go-ahead.
**Open questions:** `fauxtoe.xcodeproj/xcuserdata/.../xcschememanagement.plist` has been tracked since the initial commit despite `.gitignore`; untracking it is undecided.
**Next step:** As in the previous entry, with `fauxto/` read as `fauxtoe/`: add the app icon to `fauxtoe/Assets.xcassets/AppIcon.appiconset/`.

## 2026-09-24 14:05: Rename completed on GitHub and locally
**Completed:** GitHub repo is `ideocentric/fauxtoe`; `origin` is `git@github.com:ideocentric/fauxtoe.git` and serves `main` at `65872ad`; checkout moved to `personal/fauxtoe`. Removed a stray untracked `fauxto.xcodeproj/` that Xcode rewrote on close (byte-identical to the pre-rename project at `92b2fe7`). Unit tests pass under the new scheme.
**In flight:** none.
**Open questions:** Untracking `xcschememanagement.plist` is still undecided. Old DerivedData folder `fauxto-*` can be deleted.
**Next step:** Add the app icon to `fauxtoe/Assets.xcassets/AppIcon.appiconset/`, as in the 13:37 entry.

## 2026-09-24 19:00: App icon and Developer ID release build
**Completed:** Icon Composer icon added as `fauxtoe/AppIcon.icon` (empty `AppIcon.appiconset` removed); the build also generates flat renditions and an `.icns` for macOS 15. Bundle display name set to `fauxtoe`. `scripts/release.sh` archives and exports a universal (arm64, x86_64) app signed with Developer ID for team 3722A5T4AG, with hardened runtime and timestamp; output goes to `build/release/`. Artwork source in `outside-assets/` is excluded locally via `.git/info/exclude`.
**In flight:** Notarization. No notarytool keychain profile exists yet.
**Open questions:** Day-to-day builds stay on the free Personal Team (DBC6XYVD2X), because team 3722A5T4AG has no valid Apple Development certificate; moving the project to one team would need a new certificate. Untracking `xcschememanagement.plist` is still undecided.
**Next step:** Create a notarytool profile, run `NOTARY_PROFILE=<profile> scripts/release.sh`, then push and decide on making the repo public.

## 2026-09-24 19:30: Notarized release 1.0
**Completed:** notarytool keychain profile `fauxtoe` created by the user. `NOTARY_PROFILE=fauxtoe scripts/release.sh` produced `build/release/fauxtoe-1.0.zip` (2.2 MB): submission `11116cc0-b9b5-491d-88b6-bb8c1ac948e0` Accepted with no issues, ticket stapled. A quarantined copy unzipped from the zip passes Gatekeeper as `source=Notarized Developer ID`.
**In flight:** none. Commits since `65872ad` are not pushed.
**Open questions:** Push, and making the repo public, await the user. Untracking `xcschememanagement.plist` is still undecided.
**Next step:** Push `main`; decide whether to make the repo public and attach the zip to a GitHub release.

## 2026-09-24 19:55: Release disk image
**Completed:** `scripts/release.sh` also builds `build/release/fauxtoe-<version>.dmg` (volume `fauxtoe`, the app beside an `Applications` link, no background art). The app is notarized and stapled before packaging; the disk image is then signed, notarized and stapled itself. Run for 1.0: app submission `564fee44-3a0e-4825-ade7-0b401bb321c6` and image `7a3cbf8d-ea8b-4836-a4b3-5dad9c2218c7` both Accepted. A quarantined copy of the image passes Gatekeeper, and the app copied out of it validates its stapled ticket and passes as `Notarized Developer ID`. (`stapler validate` fails with error 68 on the app while it sits on the read-only mounted image; the ticket file there is identical, so that is a tool quirk, not a missing ticket.)
**In flight:** none. Commits since `65872ad` are not pushed.
**Open questions:** The Finder window layout of the image (icon positions, window size) is Finder's default and has not been looked at. Push and making the repo public await the user.
**Next step:** Open the disk image in Finder to check the layout; push `main`.

## 2026-09-24 20:10: Public, and release 1.0 published
**Completed:** Tag `v1.0` (annotated, at `b1a2b02`) pushed. `ideocentric/fauxtoe` made public. GitHub release "fauxtoe 1.0" published at https://github.com/ideocentric/fauxtoe/releases/tag/v1.0 with `fauxtoe-1.0.dmg` only (zip not attached). The DMG downloaded anonymously from the release matches the local build (SHA-256 `a2e41f2c…986dc`) and passes Gatekeeper when quarantined. `gh` writes ran as ideocentric via `GH_TOKEN`; the active `gh` account (simplicit-mc) was left alone.
**In flight:** none.
**Open questions:** Untracking `xcschememanagement.plist` is still undecided. The README has no install or download section yet.
**Next step:** None scheduled. For the next release, bump the version in the project, run `NOTARY_PROFILE=fauxtoe scripts/release.sh`, tag and publish the same way.
