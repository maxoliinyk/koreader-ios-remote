# KOReader Remote Labs

`KOReader Remote Labs` is a separate iOS application target with bundle identifier `git.shin.koreaderRemoteTurner.Labs`.

It is intentionally absent from the normal app's dependency graph, shared scheme, archive, and release workflow. The public app does not link MediaPlayer, AVFAudio experiments, private frameworks, or Labs source.

## Current experiments

- Foreground `AVAudioSession.outputVolume` observation with a hidden `MPVolumeView`.
- Optional playback audio category for controlled lock-screen/background observation.
- Non-invoking runtime availability checks for selected MediaRemote symbols.
- Documentation boundary for watchOS single-tap symbol research.

## Known behavior

- Physical presses change the actual system volume.
- A press at the minimum or maximum volume may not emit a changed value.
- Route changes, interruptions, Siri, calls, and other audio sessions can deactivate or reconfigure the experiment.
- Background execution is not guaranteed merely because the audio background mode exists; a legitimate active audio session is still required.
- No private symbol is invoked by the current probe.

Never submit this target to App Store review or add it to the normal release artifact.
