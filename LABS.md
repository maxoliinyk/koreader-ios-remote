# KOReader Remote Labs

`KOReader Remote Labs` is a separate iOS application with bundle identifier `git.shin.koreaderRemoteTurner.Labs`. It is for sideloaded research only. The normal app does not import Labs code or link private frameworks.

## What works without Labs

The best locked-iPhone route is already public API: add the app's **Next Page** control to the Lock Screen, Control Center, or Action Button. Its App Intent is allowed while locked and sends the request without launching the main interface.

Labs explores hardware and media-control routes that Apple does not offer as a normal page-turn API.

## iPhone experiments

Start the `KOReaderRemoteLabs` scheme after pairing in the normal app. Use the same development team for both targets. Open the normal app once after updating so its pairing secret is available to the shared Keychain group.

Tap **Start Experiment**. This does three things:

1. Starts an effectively inaudible looping `AVAudioEngine` source with the audio background mode.
2. Publishes KOReader Remote as the current Now Playing session.
3. Registers bidirectional page actions with `MPRemoteCommandCenter`.

Choose **Previous / Next** for track buttons or **10-Second Arrows** for skip buttons. Previous and Back 10 send Previous Page; Next and Forward 10 send Next Page. The mode can be changed while the session is running. Also try EarPods, Bluetooth remotes, car controls, and other media accessories.

### Volume buttons

Volume Up always sends Next Page. Volume Down always sends Previous Page. Three capture modes are available:

- **Raw Buttons** is the default. It calls `-[UIApplication setWantsVolumeButtonEvents:]` and listens for private button-down notifications. The system volume should stay fixed, and raw presses should continue at 0% and 100%.
- **Keep Centered** observes public `AVAudioSession.outputVolume` changes and immediately returns volume to 50%, preventing either endpoint from being reached. It uses the embedded `MPVolumeView` slider when available and falls back to the old private `MPMusicPlayerController` volume setter.
- **System Volume** observes public changes without correction. It changes the real volume and cannot detect further presses at 0% or 100%.

Raw locked-screen delivery and volume suppression depend on the exact iOS build and must be tested on a physical iPhone with the Labs background session active.

### MediaRemote

The probe dynamically loads `/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote`. It can inspect selected symbols and invoke `MRMediaRemoteSetCanBeNowPlayingApplication`. The public Now Playing implementation remains the primary experiment; MediaRemote behavior and ABI can change in any beta.

## watchOS 27 research

Xcode 27 beta 5 exposes one public hand-gesture shortcut: `.handGestureShortcut(.primaryAction)`, documented for Double Tap. It does not contain a public Single Tap event, recognizer, intent trigger, or extra `HandGestureShortcut` case.

watchOS 27's new Single Tap is system-owned Smart Stack behavior: it acts on the highlighted item. The supported experiment is therefore to add **Next Page** to the watch Smart Stack or Control Center and let the system invoke the control's App Intent.

Debug Watch builds include **Gesture Lab**:

- 50 Hz `CoreMotion` device-motion sampling;
- adjustable impulse threshold and cooldown;
- optional automatic Next action;
- runtime checks for private SwiftUI shortcut-task and pagination symbols.

Those private SwiftUI symbols manage shortcut highlighting/pagination. They do not expose the recognizer that produced the new system Single Tap. The motion detector is intentionally labeled a heuristic because ordinary wrist movement can cause false positives.

## Physical test checklist

### iPhone

1. Pair and test the Kindle in the normal app.
2. Add **Next Page** to the Lock Screen and verify it while locked.
3. Run `KOReaderRemoteLabs`, tap **Start Experiment**, then lock the phone.
4. Test both **Previous / Next** and **10-Second Arrows** in Now Playing.
5. In **Raw Buttons**, test Volume Up and Volume Down while unlocked, locked, and at both volume limits.
6. Test **Keep Centered** and confirm the volume returns to 50% after both buttons.
7. Record iOS build, device model, whether system volume changed, and whether both requests reached KOReader.

### Apple Watch

1. Install the Watch companion and confirm its on-screen Next button.
2. Test Double Tap with the watch app visible.
3. Add Next Page to Smart Stack/Control Center and test watchOS 27 Single Tap on the highlighted control.
4. In a Debug build, open Gesture Lab, start sampling, make several deliberate taps, then set the threshold just above normal movement peaks.
5. Enable **Send Next** only after the detector is stable.

## Important limits

Sideloading allows private API calls; it does not disable the iOS sandbox, background suspension, code-signing entitlements, or SpringBoard ownership of hardware events. Truly system-wide volume interception would require a jailbroken iPhone and a SpringBoard tweak.

The background-audio experiment takes ownership of Now Playing, can interrupt other audio, uses extra battery, and may be stopped by calls, Siri, route changes, Low Power Mode, or future OS behavior. Never include the Labs target in an App Store archive.

References: [Apple App Intent authentication](https://developer.apple.com/documentation/appintents/appintent/authenticationpolicy), [Apple controls](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system), [Apple Double Tap guidance](https://developer.apple.com/documentation/watchos-apps/enabling-double-tap), and the reverse-engineered [MediaRemote header](https://github.com/theos/headers/blob/master/MediaRemote/MediaRemote.h).
