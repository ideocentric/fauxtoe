# fauxtoe User Manual

Version 1.1

fauxtoe is a camera app for macOS, built for documentation work: stills of
circuit boards, microscope views and product shots, and frame-by-frame stop
motion. It takes full-resolution photos from any camera macOS can see, saves
them in lossless or compressed formats with quick, predictable names, and can
shoot on an interval or show earlier frames over the live picture while you
animate.

## Contents

1. [What's new in 1.1](#whats-new-in-11)
2. [Installing fauxtoe](#installing-fauxtoe)
3. [The fauxtoe window](#the-fauxtoe-window)
4. [Choosing a camera and resolution](#choosing-a-camera-and-resolution)
5. [Rotation and mirroring](#rotation-and-mirroring)
6. [Camera adjustments](#camera-adjustments)
7. [Taking photos](#taking-photos)
8. [Where and how photos are saved](#where-and-how-photos-are-saved)
9. [Naming photos](#naming-photos)
10. [Interval shooting](#interval-shooting)
11. [Onion skin](#onion-skin)
12. [A stop motion session, step by step](#a-stop-motion-session-step-by-step)
13. [Recent photos](#recent-photos)
14. [Settings](#settings)
15. [Menus and keyboard shortcuts](#menus-and-keyboard-shortcuts)
16. [Troubleshooting](#troubleshooting)
17. [Limitations](#limitations)
18. [Privacy](#privacy)
19. [License and source code](#license-and-source-code)

## What's new in 1.1

- **Onion skin.** The last one to four frames you took are drawn faintly over
  the live preview, so you can judge each move in stop motion. Photos save as a
  numbered sequence that picks up where it left off. See [Onion skin](#onion-skin).
- **Fixed: the chosen resolution is now kept.** In 1.0, the camera could replace
  the resolution you picked with one of its own once it started running, so
  photos came out at a different size from the one chosen (seen as 1920 × 1080).
  Photos and the preview now use the resolution you choose.

## Installing fauxtoe

### Requirements

- A Mac running macOS 15.7 or later, with Apple silicon or an Intel processor.
- A camera: built in, USB, Continuity Camera (an iPhone) or Desk View.

### Download and install

1. Download the disk image (`fauxtoe-1.1.dmg`) from the
   [Releases page](https://github.com/ideocentric/fauxtoe/releases/latest).
2. Open it and drag **fauxtoe** to the **Applications** folder.
3. Open fauxtoe from Applications.

fauxtoe is signed with a Developer ID and notarized by Apple, so it opens
without a security warning.

### Camera access

The first time fauxtoe starts, macOS asks whether it may use the camera. Click
**Allow**. If you choose not to, fauxtoe shows **Camera Access Is Off** with an
**Open Privacy Settings** button. Turn fauxtoe on under System Settings ›
Privacy & Security › Camera, then reopen fauxtoe.

## The fauxtoe window

fauxtoe has a single window. Closing it quits the app, which also releases the
camera for other apps.

- **The preview** fills the window and shows exactly what will be saved,
  including rotation and mirroring. The window title shows the camera's name and
  the subtitle shows the current resolution.
- **The capture bar** along the bottom holds recent photos on the left, the
  shutter button in the middle, and the interval menu (the timer icon) on the
  right.
- **The toolbar** has, from left to right: Camera, Resolution, Rotate Right,
  Mirror, Onion Skin, and Camera Controls.
- **The controls panel** opens at the right of the window with the Camera
  Controls toolbar button or ⌥⌘I. It gathers every setting in sections: Camera,
  Image, Adjustments, Capture, Onion Skin and Saving.

## Choosing a camera and resolution

### Camera

Choose a camera from the **Camera** toolbar menu, the **Camera** menu in the
menu bar, or the controls panel. The first nine cameras also have shortcuts,
⌘1 to ⌘9. Cameras you plug in or unplug while fauxtoe is running appear and
disappear on their own. If the camera in use is disconnected, fauxtoe switches
to another one. fauxtoe remembers the last camera you used.

### Resolution

Choose a resolution from the **Resolution** toolbar menu, the **Camera ›
Resolution** menu, or the controls panel. Each entry shows the photo size and
megapixels, for example `1920 × 1440 (2.8 MP)`, largest first.

Under the picker, the controls panel describes the live preview for that
resolution:

- **Preview at 30 fps** means the preview and the photo are the same size.
- **Preview 1920 × 1080 at 30 fps** (with a size) means the preview is smaller
  than the photo the camera will take.

Photos are taken at the largest still size the chosen format allows. fauxtoe
remembers the resolution separately for each camera.

The resolution decides the shape of the picture as well as its size. A camera
may offer 4:3, 16:9 and other shapes, and the preview and saved photos follow
whichever you choose.

## Rotation and mirroring

For cameras mounted sideways, upside down, or looking through a mirror:

- **Rotate**: the Rotate Right toolbar button, **Camera › Rotate Left** (⌘L) and
  **Rotate Right** (⌘R), or the Rotation picker in the controls panel or
  Settings (None, 90° Clockwise, 180°, 90° Counterclockwise).
- **Mirror**: the Mirror toolbar button, **Camera › Mirror Image**, or the
  controls panel or Settings.

Rotation and mirroring apply to the preview and to the saved file alike. They
are written into the pixels themselves rather than recorded as a flag, so every
app shows the photo the same way.

## Camera adjustments

The **Adjustments** section of the controls panel shows only what the current
camera lets macOS apps change:

- **Focus**, **Exposure** and **White Balance**: Continuous, Auto (Once) or
  Locked, as the camera allows.
- **Light**: turns on the camera's light, if it has one.
- **Click to focus**: where the camera supports it, click the preview to focus
  and expose on that spot. The pointer becomes a crosshair over the preview and a
  yellow square marks the spot.

Lock exposure and white balance to keep a series of shots consistent, which
matters for stop motion and for comparing boards.

Many USB webcams offer none of these controls to macOS apps. The panel then
says: *This camera doesn't offer focus, exposure or white balance controls to
macOS apps.*

Camera adjustments are best effort. fauxtoe passes each request to the camera
through macOS, and how a camera responds is up to its driver. Some cameras may
ignore a request, or keep adjusting on their own.

## Taking photos

Press the red shutter button, press Space, or choose **File › Take Photo**
(⌘T). The preview flashes white and, unless you turn it off in Settings, the
shutter sound plays.

### The naming sheet

With **Ask for a name after each photo** turned on (the default), a sheet shows
the photo you just took with a suggested name already selected:

- Type a name and press **Return** (or click **Save**) to save it.
- Press **Return** straight away to accept the suggestion.
- Press **Escape** (or click **Discard**) to throw the photo away.
- **Use Default Name** puts back the name fauxtoe would have used.

The sheet also shows the photo's size, the file format and the folder it will
be saved to.

Turn **Ask for a name after each photo** off, in the Saving section of the
controls panel or in Settings, to save every photo straight away under its
default name. Interval shooting and onion skin always save without asking.

## Where and how photos are saved

### The save folder

Photos go to `~/Pictures/fauxtoe` unless you choose another folder. In the
Saving section of the controls panel, or in Settings:

- **Choose…** picks a different folder. fauxtoe remembers it across launches.
- **Show in Finder** opens the folder (also **File › Show Save Folder in
  Finder**, ⇧⌘O).
- **Use Default** switches back to `~/Pictures/fauxtoe`.

**File › Choose Save Folder…** also picks a folder.

### File formats

Choose the format under **Format** in the controls panel or **File format** in
Settings:

| Format | Kind | Notes |
| --- | --- | --- |
| HEIC | Compressed | Small files at high quality. Offered only on Macs that can encode HEIC; it is the default where available. |
| JPEG | Compressed | Opens everywhere. The default on Macs without HEIC. |
| PNG | Lossless | Suits detail shots of boards and components. Larger files. |
| TIFF | Lossless | As PNG, and widely used in print and imaging work. |

fauxtoe captures each frame uncompressed, so PNG and TIFF are lossless from the
camera to the file, and HEIC and JPEG are compressed exactly once.

For HEIC and JPEG, set **Quality** in Settings › Saving, from 50% to 100%. The
default is 90%.

### What is written into each file

macOS doesn't pass on a camera's own photo metadata, so fauxtoe records what it
knows: the date and time the photo was taken (with the time zone offset), the
camera's name, and fauxtoe as the software.

### Existing files are never overwritten

If a name is already taken, fauxtoe adds a number: `name 2.jpg`, `name 3.jpg`,
and so on.

## Naming photos

Photos are named by one of two schemes, chosen under **Naming** in the
controls panel or Settings. Both show the name the next photo will get, under
**Next file**.

### Date and time

Names come from a template, by default `fauxtoe {date} at {time}`, which gives
names such as `fauxtoe 2026-10-05 at 14.05.32.heic`. The template understands:

| Token | Becomes | Example |
| --- | --- | --- |
| `{date}` | The date | 2026-10-05 |
| `{time}` | The time | 14.05.32 |
| `{n}` | A sequence number that goes up with each photo saved under the default name | 0007 |
| `{camera}` | The camera's name | FaceTime HD Camera |

In Settings, **Template tokens** lists these, and **Restore Default Template**
puts the original back.

When you type your own name in the naming sheet, the next photo suggests the
next name in that series: `board-01` is followed by `board-02`, and `board 9`
by `board 10`. A name without a number at the end gets ` 2` added. Accepting
the default name ends the series.

### Name and number

Names are a root you choose (by default `image`) plus a three-digit number:
`image-001`, `image-002`, and so on. The number goes past 999 as needed
(`image-1000`). Numbering continues from the highest number already in the
save folder, so a series picks up where it left off after you quit and reopen
fauxtoe.

Name and number naming suits frame sequences: stop motion and video tools can
import `scene-001`, `scene-002`, ... directly.

## Interval shooting

Interval shooting takes a photo now and then another every few seconds until
you stop it, for stop motion and time-lapse.

1. Choose an interval from the timer menu in the capture bar, **Camera ›
   Interval**, the Capture section of the controls panel, or Settings: Single
   Photo, or Every Second, Every 2, 3, 5, 10, 15, 30 or 60 Seconds.
2. Press the shutter (Space or ⌘T). It shows a timer icon while an interval is
   set.
3. A badge at the top of the preview shows how many photos have been taken and
   the seconds to the next one.
4. Press the stop button (Space) or choose **File › Stop Interval Shooting**
   (⌘.) to finish.

Shots keep to a fixed schedule from the start of the run, so the timing doesn't
drift. If saving a photo takes longer than the interval, the shot that falls
due is skipped rather than taken late. Interval photos save without asking for
a name. The interval can't be changed during a run.

## Onion skin

Onion skin is for stop motion. While it's on, the last frames you took are
drawn faintly over the live preview, so you can see where things were and judge
how far to move them for the next frame. It works with single photos and with
interval shooting.

### Turning it on

Use any of these:

- the **Onion Skin** toolbar button;
- **Camera › Onion Skin** (⌥⌘O);
- the **Onion Skin** switch in the Onion Skin section of the controls panel.

Onion skin can't be turned on or off during an interval run.

### Settings

In the Onion Skin section of the controls panel:

| Setting | What it does | Range | Default |
| --- | --- | --- | --- |
| **Opacity** | How strongly the newest earlier frame shows | 10% to 90% | 40% |
| **Show N frames** | How many earlier frames to show | 1 to 4 | 1 |
| **Sequence** | The name the frames are saved under | Any name | `frame` |
| **Next frame** | The file name the next photo will get (shown while on) | | |

### How the frames are drawn

The newest earlier frame is drawn at the opacity you set, and each older frame
at half the opacity of the one before. At 50%:

| Frame | Opacity |
| --- | --- |
| Newest | 50% |
| 2nd | 25% |
| 3rd | 12.5% |
| Oldest | 6.25% |

Older frames are drawn on top of newer ones, so each step back in time is
clearly fainter. Every frame you show also dims the live picture a little:
with one frame at 50%, the live picture and the frame show equally, and with
four frames at 50% the live picture shows at about a third of its strength.
Show fewer frames, or lower the opacity, to keep the live picture brighter.

The frames stay lined up with the live picture when you resize the window or
open and close the controls panel.

### Saving and numbering

While onion skin is on:

- every photo saves straight away, with no naming sheet;
- photos are named as a numbered sequence under the **Sequence** name:
  `frame-001`, `frame-002`, and so on;
- numbering continues from the highest number already in the save folder.

Your normal naming settings are left alone and apply again when you turn onion
skin off. Photos taken with onion skin off never use up sequence numbers.

The sequence name can only be changed while onion skin is off, because a new
name starts a different sequence.

### Changing the camera setup starts a new sequence

You can change the camera, resolution, rotation or mirroring at any time. Frames
taken before the change would no longer line up with the live picture, so they
are hidden, and a note in the controls panel says that a new sequence starts
with the next file name. Numbering carries on: if the last frame was
`frame-012`, the next is `frame-013`.

Going back to the earlier setup doesn't bring the hidden frames back. New
frames build up on screen again as you shoot.

### Picking up where you left off

When you turn onion skin on, or reopen fauxtoe with it on, fauxtoe looks in
the save folder for the sequence's most recent frames and shows them again,
but only if they were taken with the same camera, resolution, rotation and
mirroring as now. Otherwise the frames stay hidden and the note says a new
sequence starts; numbering still continues.

## A stop motion session, step by step

1. Mount the camera and choose it, then choose a resolution. Rotate or mirror
   the picture if the camera is mounted oddly.
2. If the camera offers them, lock exposure and white balance in the
   Adjustments section so the light doesn't drift between frames.
3. Open the controls panel (⌥⌘I). In the Onion Skin section, type a Sequence
   name such as `walk-cycle`, then turn **Onion Skin** on. Set **Show N frames**
   to 2 and **Opacity** to about 50%.
4. Take the first frame (Space).
5. Move your subject. The previous frames show over the live picture; line up
   the move and take the next frame. Repeat.
6. For hands-free shooting, set an interval instead and move the subject
   between shots. The frames on screen update after every shot.
7. To use a second camera for some shots, switch cameras. Numbering carries on
   from where it was, and the on-screen frames start afresh for the new view.
   When you switch back, they start afresh again.
8. Import `walk-cycle-001`, `walk-cycle-002`, ... from the save folder into
   your video or animation tool as an image sequence.

## Recent photos

Thumbnails of the photos taken since fauxtoe opened (up to the last 60) run
along the left of the capture bar, oldest on the left and newest on the right.
When there are more than fit, use the arrows to page back and forth; a new
photo brings the strip back to the newest end.

- **Double-click** a thumbnail to open the photo in its default app.
- **Drag** a thumbnail to Finder or another app to copy the photo.
- **Right-click** for **Open**, **Show in Finder** and **Move to Trash**.

If a photo has been moved or deleted outside fauxtoe, fauxtoe says so and
removes its thumbnail.

## Settings

Open Settings with **fauxtoe › Settings…** (⌘,).

**Saving**
- **Folder**, with **Choose…**, **Show in Finder** and **Use Default**.
- **File format**, and **Quality** for HEIC and JPEG.
- **Naming**: the scheme, the template or name, **Template tokens**, **Restore
  Default Template**, and **Next file**.
- **Ask for a name after each photo**.

**Capture**
- **Interval**.
- **Play shutter sound**.
- **Rotation** and **Mirror image**.

Everything in Settings is also in the controls panel, except Quality, the
shutter sound and the template help. Onion skin settings are in the controls
panel only.

## Menus and keyboard shortcuts

| Action | Shortcut | Menu |
| --- | --- | --- |
| Take a photo, or start interval shooting | Space or ⌘T | File › Take Photo / Start Interval Shooting |
| Stop interval shooting | Space or ⌘. | File › Stop Interval Shooting |
| Show the save folder in Finder | ⇧⌘O | File › Show Save Folder in Finder |
| Choose a save folder | | File › Choose Save Folder… |
| Switch to camera 1 to 9 | ⌘1 to ⌘9 | Camera |
| Choose a resolution | | Camera › Resolution |
| Rotate left / right | ⌘L / ⌘R | Camera › Rotate Left / Rotate Right |
| Mirror the image | | Camera › Mirror Image |
| Turn onion skin on or off | ⌥⌘O | Camera › Onion Skin |
| Choose an interval | | Camera › Interval |
| Show or hide the controls panel | ⌥⌘I | View › Show / Hide Camera Controls |
| Settings | ⌘, | fauxtoe › Settings… |

In the naming sheet, Return saves and Escape discards.

## Troubleshooting

**Camera Access Is Off.** fauxtoe isn't allowed to use the camera. Click **Open
Privacy Settings**, turn fauxtoe on under Privacy & Security › Camera, then
reopen fauxtoe.

**No Camera Connected.** Connect a camera; it appears on its own.

**The Camera Isn't Available.** The camera couldn't be started, often because
another app is using it. Quit the other app and click **Try Again**.

**Photos are a different size from the resolution I chose.** This was a bug in
1.0 and is fixed in 1.1. If you still see it, please report it with the log
described below.

**HEIC isn't in the format list.** This Mac can't encode HEIC. Use JPEG for
compressed photos, or PNG or TIFF for lossless ones.

**The onion skin frames disappeared.** The camera, resolution, rotation or
mirroring changed, so the earlier frames no longer line up and a new sequence
started. The note in the Onion Skin section says so. See [Changing the camera
setup starts a new sequence](#changing-the-camera-setup-starts-a-new-sequence).

**A recent photo is missing.** It was moved or deleted outside fauxtoe, so it
has been removed from the strip. The file itself is wherever it was moved to.

### The diagnostic log

fauxtoe writes its camera steps to the macOS system log: starting and stopping
the camera, quitting, the resolution in use (`Format:` and `Running:` lines),
the size of each photo taken (`Captured`), and where the preview is drawn
(`Preview:`). When reporting a problem, include what this shows. To watch it
live while you use fauxtoe, run this in Terminal:

```sh
log stream --level info --predicate 'subsystem == "com.ideocentric.fauxtoe"'
```

To see the last ten minutes after something went wrong:

```sh
log show --last 10m --info --predicate 'subsystem == "com.ideocentric.fauxtoe"'
```

Report problems at
[github.com/ideocentric/fauxtoe/issues](https://github.com/ideocentric/fauxtoe/issues).

## Limitations

- **Most USB webcams offer no adjustments to macOS apps.** macOS only offers
  the focus, exposure and white balance controls that a camera's driver
  reports, and most USB webcams report none.
- **Camera adjustments are best effort.** How a camera responds to focus,
  exposure and white balance requests is up to its driver. Some cameras may
  ignore a request, or keep adjusting on their own.
- **The camera's own photo metadata isn't available on macOS.** fauxtoe writes
  the capture time, camera name and software name instead.
- **Zoom and exposure compensation aren't available** to macOS camera apps.

## Privacy

fauxtoe runs in the macOS app sandbox. It can use the camera, read and write
your Pictures folder, and read and write only the other folders you choose.
Photos never leave your Mac, and fauxtoe makes no network connections.

## License and source code

fauxtoe is free software, licensed under the GNU Affero General Public License,
version 3 or later. The source code is at
[github.com/ideocentric/fauxtoe](https://github.com/ideocentric/fauxtoe).

Copyright (C) 2026 Matt Comeione.
