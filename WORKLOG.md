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

## 2026-09-24 18:58: App icon and Developer ID release build
**Completed:** Icon Composer icon added as `fauxtoe/AppIcon.icon` (empty `AppIcon.appiconset` removed); the build also generates flat renditions and an `.icns` for macOS 15. Bundle display name set to `fauxtoe`. `scripts/release.sh` archives and exports a universal (arm64, x86_64) app signed with Developer ID for team 3722A5T4AG, with hardened runtime and timestamp; output goes to `build/release/`. Artwork source in `outside-assets/` is excluded locally via `.git/info/exclude`.
**In flight:** Notarization. No notarytool keychain profile exists yet.
**Open questions:** Day-to-day builds stay on the free Personal Team (DBC6XYVD2X), because team 3722A5T4AG has no valid Apple Development certificate; moving the project to one team would need a new certificate. Untracking `xcschememanagement.plist` is still undecided.
**Next step:** Create a notarytool profile, run `NOTARY_PROFILE=<profile> scripts/release.sh`, then push and decide on making the repo public.

## 2026-09-24 19:27: Notarized release 1.0
**Completed:** notarytool keychain profile `fauxtoe` created by the user. `NOTARY_PROFILE=fauxtoe scripts/release.sh` produced `build/release/fauxtoe-1.0.zip` (2.2 MB): submission `11116cc0-b9b5-491d-88b6-bb8c1ac948e0` Accepted with no issues, ticket stapled. A quarantined copy unzipped from the zip passes Gatekeeper as `source=Notarized Developer ID`.
**In flight:** none. Commits since `65872ad` are not pushed.
**Open questions:** Push, and making the repo public, await the user. Untracking `xcschememanagement.plist` is still undecided.
**Next step:** Push `main`; decide whether to make the repo public and attach the zip to a GitHub release.

## 2026-09-24 19:54: Release disk image
**Completed:** `scripts/release.sh` also builds `build/release/fauxtoe-<version>.dmg` (volume `fauxtoe`, the app beside an `Applications` link, no background art). The app is notarized and stapled before packaging; the disk image is then signed, notarized and stapled itself. Run for 1.0: app submission `564fee44-3a0e-4825-ade7-0b401bb321c6` and image `7a3cbf8d-ea8b-4836-a4b3-5dad9c2218c7` both Accepted. A quarantined copy of the image passes Gatekeeper, and the app copied out of it validates its stapled ticket and passes as `Notarized Developer ID`. (`stapler validate` fails with error 68 on the app while it sits on the read-only mounted image; the ticket file there is identical, so that is a tool quirk, not a missing ticket.)
**In flight:** none. Commits since `65872ad` are not pushed.
**Open questions:** The Finder window layout of the image (icon positions, window size) is Finder's default and has not been looked at. Push and making the repo public await the user.
**Next step:** Open the disk image in Finder to check the layout; push `main`.

## 2026-09-24 20:00: Public, and release 1.0 published
**Completed:** Tag `v1.0` (annotated, at `b1a2b02`) pushed. `ideocentric/fauxtoe` made public. GitHub release "fauxtoe 1.0" published at https://github.com/ideocentric/fauxtoe/releases/tag/v1.0 with `fauxtoe-1.0.dmg` only (zip not attached). The DMG downloaded anonymously from the release matches the local build (SHA-256 `a2e41f2c…986dc`) and passes Gatekeeper when quarantined. `gh` writes ran as ideocentric via `GH_TOKEN`; the active `gh` account (simplicit-mc) was left alone.
**In flight:** none.
**Open questions:** Untracking `xcschememanagement.plist` is still undecided. The README has no install or download section yet.
**Next step:** None scheduled. For the next release, bump the version in the project, run `NOTARY_PROFILE=fauxtoe scripts/release.sh`, tag and publish the same way.

## 2026-09-24 20:07: Checkpoint after public release 1.0
**Completed:** README download section (`20defe7`). `xcschememanagement.plist` untracked (`d6749ed`); a fresh clone still builds and passes unit tests with the auto-generated `fauxtoe` scheme. All work through `d6749ed` is pushed; `ideocentric/fauxtoe` is public with release v1.0 (DMG). `CLAUDE.local.md` updated to say the repo is public.
**In flight:** none.
**Open questions:** none.
**Next step:** For the next release: raise `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION`) in `fauxtoe.xcodeproj`, commit, run `NOTARY_PROFILE=fauxtoe scripts/release.sh`, then tag `v<version>`, push the tag over SSH, and run `gh release create` as ideocentric (`GH_TOKEN="$(gh auth token --user ideocentric)"`) with `build/release/fauxtoe-<version>.dmg`.

## 2026-10-05 16:58: Onion skin, and the resolution menu fixed
**Completed:**
- Found a 1.0 bug: the Resolution menu never took effect. The capture session replaced the chosen format with its own (1920x1080 on the test camera) when it started running and on every configuration commit while running. Shown by size logging (`d7a34db`): `Format: 1920×1440` logged before the session started, then every capture was 1920×1080. Fixed by keeping the camera locked for configuration after a format is set (`7b1af5c`); the UI now reads the format back after the commit. On the user's camera, captures then followed the choice (1920×1440, 640×480). `.inputPriority`, the iOS answer, does not exist on macOS.
- Crash fixed (`2e91591`): before the session connects, the preview layer's converted rect is `CGRect.null` (infinite origin), and converting it to `Int` for the log trapped.
- Onion skin (branch `onion-skin`): one to four previous frames over the preview, opacity halving per frame and the oldest drawn on top; works for single shots and interval runs; photos save as a numbered sequence under their own root without the name prompt, numbering resuming from the folder. Changing camera, resolution, rotation or mirroring hides the frames and starts a new sequence; the setup is saved with the sequence so a relaunch only reloads frames from the same setup. Skins are fitted with `AVMakeRect` from the view bounds, because the preview layer's own rect lags a layout pass during a live resize.
- User manual written (`docs/user-manual.md`, linked from the README), every control name, default and message taken from the source. PDF rendered for the release to `build/release/fauxtoe-1.1-user-manual.pdf` (13 pages, Letter; pages checked by eye) with pandoc to HTML, then Playwright 1.60.0's bundled Chromium (cached `chromium-1223`), installed in the session scratchpad. Text only; screenshots deferred to a later release. The renderer is now in the repo (`scripts/render-manual.sh`, `scripts/manual/`), and `scripts/release.sh` runs it before notarizing and puts `fauxtoe User Manual.pdf` in the DMG beside the app; it refuses to render unless the manual says `Version <app version>`. Checked with an un-notarized run at 1.1 (build 2): the mounted DMG holds the app (1.1, signature valid), the Applications link and the 13-page PDF, byte-identical to `build/release/fauxtoe-1.1-user-manual.pdf`; the DMG is signed by Developer ID 3722A5T4AG. That run took about 20 minutes, most of it codesign waiting on a Keychain access prompt.
- 45 unit tests pass. Every commit on the branch builds on its own (checked in a scratch worktree, later commits built and tested in order). The user tried it on hardware and reported it working as desired.

**In flight:** Branches `resolution-fix` (logging, crash fix, resolution fix) and `onion-skin` (on top of it) are local only; nothing is pushed.

**Open questions:**
- A first version locked camera, resolution, rotation and mirror while onion skin was on; the next commit replaced the locks with starting a new sequence. Decided: squash the pair (done, `6c899b2`, tree unchanged).
- Decided: one full release with onion skin, its notes calling out the resolution fix. In 1.0 the chosen resolution can be replaced by the session's own; seen as 1920x1080 on the test camera, other cameras untested.
- Decided: the size logging stays, for diagnosing future regressions.
- Focus and exposure with the device lock held: checked on the test camera, which offers both; its continuous auto focus and exposure keep adjusting. Decided: camera adjustments are best effort, with no per-camera work; noted in the README's Limitations.

**Next step:** Decide the squash and merge order, then merge to `main` over SSH as ideocentric and, if releasing, follow the release steps in the 2026-09-24 20:07 entry.

## 2026-10-05 21:43: Release 1.1 published
**Completed:** `onion-skin` (which includes `resolution-fix`) fast-forwarded into `main` at `b9b009c`; annotated tag `v1.1` pushed over SSH as ideocentric. `NOTARY_PROFILE=fauxtoe scripts/release.sh` built 1.1 (build 2); Apple accepted the app and the DMG, both stapled. The DMG and the zip each hold `fauxtoe.app` and `fauxtoe User Manual.pdf` (the DMG also an Applications link). GitHub release "fauxtoe 1.1" at https://github.com/ideocentric/fauxtoe/releases/tag/v1.1 with `fauxtoe-1.1.dmg`, `fauxtoe-1.1.zip` and `fauxtoe-1.1-user-manual.pdf`; `releases/latest` points to it. All three downloaded anonymously match the local build (SHA-256 DMG `584c3d17…f4502d`, zip `d01ce3a4…f5333a`, PDF `87c67fd7…6bfb2`), and the downloaded DMG passes Gatekeeper with quarantine set. `gh` was switched to ideocentric for the release and restored to simplicit-mc.
**In flight:** none.
**Open questions:** Local branches `onion-skin` and `resolution-fix` are fully merged and can be deleted.
**Next step:** None scheduled. For the next release: update `Version` in `docs/user-manual.md` along with `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` (release.sh stops otherwise), then run `NOTARY_PROFILE=fauxtoe scripts/release.sh`, tag, push, and create the release with gh switched to ideocentric and restored after.

## 2026-10-05 22:44: Checkpoint after release 1.1
**Completed:** Release 1.1 is public (https://github.com/ideocentric/fauxtoe/releases/tag/v1.1): onion skin, the Resolution menu fix, and the user manual (`docs/user-manual.md`, shipped as a PDF in the DMG and the zip). `main` at `bb65610` is pushed; tag `v1.1` is at `b9b009c`. Local branches `onion-skin` and `resolution-fix` were merged and deleted, which closes the open question in the 21:43 entry. Working tree clean.
**In flight:** none.
**Open questions:**
- The resolution fix is verified on one camera only (4:3 formats, then a 16:9 check reported working). Other cameras are untested.
- Camera adjustments are best effort; checked on the test camera only.
- Manual screenshots were deferred to a later release.
**Next step:** None scheduled. For the next release, set `Version <new>` in `docs/user-manual.md` and raise `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in `fauxtoe.xcodeproj` (`scripts/release.sh` stops if they differ), then run `NOTARY_PROFILE=fauxtoe scripts/release.sh`, watch for the Keychain prompt from codesign, tag, push over SSH, and create the release with gh switched to ideocentric and restored after.

## 2026-10-05 23:04: Roadmap started; context files updated
**Completed:** `docs/roadmap.md` added and pushed (`2387822`), recording two undesigned ideas: stop motion playback (in fauxtoe or a separate app, undecided) and re-shooting from a keyframe. Context updated: `CLAUDE.local.md` now covers the size logging, the user manual and the release requirements (not tracked by git); global `~/.claude/CLAUDE.md` gained the pandoc-to-Chromium PDF route (`7d26f3c` in `~/.claude`).
**In flight:** none.
**Open questions:**
- Playback: build into fauxtoe, or a separate app?
- Keyframe re-shooting: whether re-shot frames overwrite, insert or branch (this decides numbering); whether the onion skin shows the keyframe only or the frames before it too; whether re-shot frames must match the keyframe's camera setup. All recorded in `docs/roadmap.md`.
- Carried over: the resolution fix and the best-effort camera adjustments are verified on one camera only; manual screenshots deferred.
**Next step:** None scheduled. To resume the roadmap, decide in-app versus separate app for playback, using the questions in `docs/roadmap.md`, before any design work.
