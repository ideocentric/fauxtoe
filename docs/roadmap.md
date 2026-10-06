# Roadmap

Ideas for future versions. Nothing here is scheduled or designed yet.

## Stop motion playback

Play a finished sequence back as an animation, to check the motion and the
easing between frames.

**Open question:** build this into fauxtoe, or split it off as a separate app.
Undecided.

Recorded 2026-10-05.

## Re-shooting from a keyframe

**Use case:** a sequence is finished, but on playback the easing between some
frames is off. You go to the frame where it goes wrong and set it as a
keyframe. The frame you recorded earlier then becomes the onion skin layer, so
you can line up the next frame at the position you want.

This depends on playback, or at least some way of browsing the sequence to
reach a frame.

**Open questions:**
- What happens to the frames after the keyframe: are re-shot frames saved over
  them, inserted between them, or saved as a new branch of the sequence? This
  decides the numbering (`frame-013` replaced, or something like `frame-013a`).
- Is the onion skin only the keyframe itself, or the keyframe and the frames
  just before it, as with live onion skin?
- Do re-shot frames have to match the setup the keyframe was taken with
  (camera, resolution, rotation, mirroring), as live onion skin requires?

**Existing pieces to build on:** onion skin already loads earlier frames of a
sequence from disk (`AppModel.resumeOnionSkin`, `OnionSkin.image`), lists a
sequence's files in order (`FileNaming.numberedFiles`), and remembers the setup
a sequence was shot with (`OnionSkinSequence`).

Recorded 2026-10-05.
