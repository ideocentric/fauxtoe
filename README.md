# fauxto

A small macOS camera app for taking stills with whatever camera is near your
desk: a USB webcam over a circuit board, a camera on a desktop microscope, or a
setup for product shots. It works like Photo Booth, minus the effects, plus the
things you want for documentation work: full-resolution capture, lossless
formats, quick file naming, rotation for oddly mounted cameras, and interval
shooting for stop motion and time-lapse.

## Features

- **Any camera macOS can see.** Built-in, USB (UVC), Continuity Camera and Desk
  View cameras. Cameras connected or disconnected while the app is running are
  picked up automatically, and the last one used is remembered.
- **Every supported resolution.** Photos are taken at the largest still size the
  chosen format allows. The choice is remembered per camera.
- **Lossless or compressed.** HEIC, JPEG, PNG or TIFF. Frames are captured
  uncompressed, so PNG and TIFF are lossless end to end, and HEIC and JPEG are
  compressed exactly once.
- **Rotation and mirroring** for cameras mounted sideways, upside down or seen
  through a mirror. They apply to the preview and to the saved file alike, and
  are baked into the pixels, so every viewer shows the photo the same way.
- **Camera controls** where the camera exposes them: focus, exposure and white
  balance modes, the light, and click-to-focus on the preview. Locking exposure
  and white balance keeps a series of shots consistent.
- **Quick naming.** After each photo, a sheet shows it with a suggested name
  selected: type a name and press Return, or press Escape to discard. Photos can
  also save straight away under a default name.
- **Interval shooting.** One photo now, then another every N seconds until you
  stop, for stop motion and time-lapse.
- **Recent photos** along the bottom of the window. Double-click to open one in
  its default app, drag one out to copy it, or right-click for Show in Finder
  and Move to Trash.

## Requirements

- macOS 15.7 or later
- Xcode 26 to build

## Building

Open `fauxto.xcodeproj` in Xcode and run the `fauxto` scheme. The first launch
asks for camera access.

From the command line:

```sh
xcodebuild -project fauxto.xcodeproj -scheme fauxto build
xcodebuild -project fauxto.xcodeproj -scheme fauxto -only-testing:fauxtoTests test
```

If `xcodebuild` reports that the active developer directory is the Command Line
Tools, prefix the command with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## Using fauxto

### Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Take a photo, or start interval shooting | Space or ⌘T |
| Stop interval shooting | Space or ⌘. |
| Switch to camera 1 to 9 | ⌘1 to ⌘9 |
| Rotate left / right | ⌘L / ⌘R |
| Show or hide camera controls | ⌥⌘I |
| Show the save folder in Finder | ⇧⌘O |
| Settings | ⌘, |

In the naming sheet, Return saves and Escape discards.

### Where photos are saved

Photos go to `~/Pictures/fauxto` unless you choose another folder, either from
the Saving section of the controls panel or from Settings. A chosen folder is
remembered across launches, and Use Default switches back.

### Naming

There are two naming schemes, set in the controls panel or in Settings. Both
show the name the next photo will get.

- **Date and time** uses a template, by default `fauxto {date} at {time}`. The
  template understands `{date}` (2026-09-23), `{time}` (14.05.32), `{n}` (a
  sequence number, 0007) and `{camera}` (the camera's name). If you type your own
  name in the sheet, the next photo suggests the next name in that series, so
  `board-01` is followed by `board-02`.
- **Name and number** uses a root you choose plus a three-digit counter:
  `imagename-001.jpg`, `imagename-002.jpg`, and so on. Numbering continues from
  the highest number already in the folder, so a series picks up where it left
  off after a relaunch.

Existing files are never overwritten. A name that is already taken gets a
number appended, such as `name 2.jpg`.

### Interval shooting

Choose an interval from the timer menu beside the shutter, the Camera menu, the
controls panel or Settings: Single Photo, or every 1, 2, 3, 5, 10, 15, 30 or 60
seconds.

With an interval set, the shutter takes a photo immediately and then one at
each interval until you press Stop (Space or ⌘.). A small badge at the top of
the preview shows how many photos have been taken and the time to the next one.
Shots follow a fixed schedule from the start of the run, so timing does not
drift; if a save overruns the next slot, that shot is skipped rather than taken
late.

Interval photos save without asking for a name. Name and number naming (for
example `scene-001`, `scene-002`) gives a frame sequence that stop-motion and
video tools can import directly.

## Limitations

- **Most USB webcams expose no adjustments to macOS apps.** AVFoundation on
  macOS only offers focus, exposure and white balance controls that the camera's
  driver reports, and most UVC webcams report none. The controls panel says so
  when a camera has nothing to adjust. Direct UVC control would need a separate
  USB implementation.
- **The camera's own photo metadata is not available on macOS.** fauxto writes
  the capture time, camera name and software name into each file instead.
- **Zoom and exposure compensation are not available** in AVFoundation on macOS.

## Privacy

fauxto is sandboxed. It can use the camera, read and write `~/Pictures`, and
read and write only the folders you choose. Photos never leave your Mac.

## Troubleshooting

Session start and stop, and each step of quitting, are written to the system
log:

```sh
log show --last 10m --predicate 'subsystem == "com.ideocentric.fauxto"'
```

## Project layout

| Path | Contents |
| --- | --- |
| `fauxto/Camera/` | `CaptureEngine`, which owns the capture session, and the camera value types |
| `fauxto/Saving/` | Rotation, mirroring and encoding (`PhotoRenderer`), and the save folder (`SaveLocation`) |
| `fauxto/Models/` | Output formats, file naming and user preferences |
| `fauxto/Views/` | Preview, capture bar, controls panel, naming sheet and Settings |
| `fauxto/AppModel.swift` | App state: camera selection, capture, interval runs, saving and recent photos |
| `fauxto/FauxtoCommands.swift` | Menu bar commands |
| `fauxto/*.xcstrings` | String Catalogs holding all user-facing text |
| `fauxtoTests/` | Unit tests for naming, rendering, encoding and localization |
| `scripts/sync-strings.sh` | Adds new interface strings to the String Catalog from the command line |

## Translating

fauxto is ready for translation, though English is the only language so far.
All user-facing text lives in two String Catalogs:

- `fauxto/Localizable.xcstrings`: the app's interface and messages.
- `fauxto/InfoPlist.xcstrings`: the camera permission prompt and the About box.

To add a language, open the project in Xcode, choose the project in the
navigator, add the language under Info › Localizations, then fill in the
catalogs. Some strings have plural forms, for example "%lld photos"; the catalog
editor shows the forms your language needs. The file name tokens `{date}`,
`{time}`, `{n}` and `{camera}` must stay as written.

Tools that read `.xcstrings` files, such as Weblate or Crowdin, can be used
instead of Xcode.

Xcode's editor adds new strings to the catalog as you write code. When working
from the command line, run `scripts/sync-strings.sh` after changing any
interface text.

To check a layout without translations, edit the scheme's Run options and set
App Language to Accented Pseudolanguage (anything not accented was missed),
Double-Length Pseudolanguage (finds truncation) or Right-to-Left Pseudolanguage.

## License

Copyright (C) 2026 Matt Comeione

fauxto is free software: you can redistribute it and/or modify it under the
terms of the GNU Affero General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.

fauxto is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

The full text is in [LICENSE](LICENSE). Each source file carries the SPDX
identifier `AGPL-3.0-or-later`.

In short: you may use, study, share and change fauxto, but if you distribute it,
or a modified version, you must make the complete corresponding source available
under the same license. The same applies if you let people use a modified
version over a network.

### Contributing

Contributions are welcome, translations included. By submitting a change you
agree that it is licensed under the same terms, AGPL-3.0-or-later.
