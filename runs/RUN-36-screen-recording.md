# Run 36 — Screen recording: microphone and screen capture

## Why
Insert > Record Screen didn't work. The recording dialog put the Mac's microphone in the Speakers list and left the Microphone list empty and greyed out. Once that was fixed, recordings still had no sound.

## Microphone

### Cause
- The dialog's device lists come from Articulate's 32-bit recording helper, `Articulate.Capture.Adapter.App.exe`, through its native `VistaCoreSoundAPIWrap.dll`. It lists the capture endpoints, matches each one to a wave-in device, then calls `mixerOpen` with `MIXER_OBJECTF_WAVEIN` and that wave-in ID and reads the line's component type. `MIXERLINE_COMPONENTTYPE_SRC_MICROPHONE` (0x1003) puts a device in the Microphone list; anything else goes under Speakers.
- Wine's `mixerOpen` ignored the object type in `fdwOpen` and took the wave-in ID as a mixer ID. Wave-in 0 became mixer 0, the first output device, whose `MIXERLINE_COMPONENTTYPE_DST_WAVEIN` query fails with `MIXERR_INVALLINE`. The helper then kept its default, non-microphone type.
- With the mic listed correctly, macOS still sent silence. The unified log said `Refusing authorization request for service kTCCServiceMicrophone … without NSMicrophoneUsageDescription key`. macOS charges the mic to the app bundle that started Storyline, which is the Articulate 360 launcher when Storyline is opened from the Desktop App, and none of the launchers had a usage string, so macOS refused without asking.

### Fix: patch 0034 and the launchers
- `tools/wine-patches/0034-winmm-mixerOpen-honours-the-object-type-in-fdwOpen.patch` (+11 Wine lines): for `MIXER_OBJECTF_WAVEOUT`, `WAVEIN`, `HWAVEOUT` and `HWAVEIN`, `mixerOpen` first resolves the ID or handle to its mixer with `mixerGetID`, as Windows does. `build-ntdll.sh` builds and installs the 64- and 32-bit `winmm.dll`; the helper is 32-bit.
- `Info.plist`, `Info-storyline.plist` and the bridge that `install-launchers.sh` builds now carry `NSMicrophoneUsageDescription` and `NSCameraUsageDescription` (Storyline can also record the webcam). The bridge gets them because `osacompile`'s defaults read "This script needs access to your microphone to run."

### Results
- A standalone 32-bit test that opens the mixer the way the helper does: component type 0x1003 (`SRC_MICROPHONE`) with the patch, `MIXERR_INVALLINE` without it.
- In Storyline 360, the recording dialog lists the Mac mic under Microphone.
- After the launcher change, macOS asked for microphone access once and logged it as allowed (`auth_value=2`), and the next recording had narration. A recording started before Allow stays silent, because macOS keeps feeding silence to a stream that was opened while access was denied.

### Limits
- The dialog's level meter stays flat while the narration records. The recorder reads the level with `VistaGetEndpointMeter` in `VistaCoreSoundAPIWrap.dll`, which uses Windows' `IAudioMeterInformation`, and Wine doesn't implement that interface, so activating it fails and the meter reads zero.
