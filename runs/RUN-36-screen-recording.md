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

## Screen capture

### Cause
- The recorder copies the screen with GDI, blitting from a screen DC. On Windows that read goes to the display driver. Wine's Mac driver has no `GetImage`, so the read fell through to the null driver, and every copy failed and left the frame black. A test program doing the same `BitBlt` from `GetDC(0)` got black frames too.
- The capture helper is not DPI-aware, so on a Retina screen in Retina mode it sees a 1440×900 desktop while the screen is 2880×1800 pixels.

### Fix: patch 0035
`tools/wine-patches/0035-winemac-read-the-screen-for-GDI-screen-DCs-through-ScreenCaptureKit.patch` (+425 Wine lines, 297 of them the new file):
- **`gdi.c`:** a new `macdrv_GetImage` answers reads from screen DCs. It adds the DC origin to the requested rectangle, scales it from the caller's virtual screen to raw pixels, which is what makes the DPI-unaware helper get the whole screen instead of its top-left quarter, and converts it to Mac coordinates. It returns a top-down 32-bit image of exactly the size asked for.
- **`cocoa_screencapture.m`:** the first read starts a ScreenCaptureKit stream for that display at its full pixel size, BGRA, at most 30 frames per second and without the cursor, because the recorder draws its own as it does on Windows. Each read copies the newest frame, scaled with vImage when the sizes differ. The stream stops 3 s after the last read. If macOS refuses the stream, the driver stops trying for 10 s. The first read waits up to 2 s for a frame.
- **Fallback:** when there is no stream frame (no permission, macOS before 12.3, or a rectangle spanning two displays), `CGWindowListCreateImage` takes a one-off screenshot. The macOS 15 SDK marks it obsolete, so it is looked up with `dlsym`. The first read also asks macOS for Screen Recording permission.
- `Makefile.in` adds the new file and the Accelerate, CoreMedia and ScreenCaptureKit frameworks. `build-ntdll.sh` applies 0035 after 0033 in the winemac step, and the Makefile refresh there now covers it.

### Results
- The CoreGraphics version, run from a test program in Cursor's terminal: a DPI-unaware caller got the whole screen at 1440×900 in about 54 ms per grab, and a DPI-aware caller got 2880×1800 in about 120 ms. The frames showed only the wallpaper and menu bar, because Cursor has no Screen Recording permission and macOS leaves other apps' windows out.
- In Storyline 360, macOS asked for Screen Recording permission for the Articulate 360 launcher, and a recording with the CoreGraphics version completed, but it was slow. About two minutes later, while Storyline processed the video, the Mac panicked with an NVMe command timeout in the T2 storage controller, the second such panic that day. That comes from the T2's own firmware, which software shouldn't be able to trigger, but heavy disk writes preceded both.
- Timing the one-off capture calls natively gave roughly 30–200 ms per frame on this Mac (measured under load after the reboot), which is why the ScreenCaptureKit stream replaced them.
- The ScreenCaptureKit version builds without warnings, and the test program's captures still work through the fallback, at about 25 ms per frame. The stream path itself is untested: macOS only lets processes started by the permitted launcher use it, so a recording in Storyline is the test.

### Limits
- Not yet confirmed in Storyline: that the stream is used, the recordings show real windows, and the recording runs at a usable speed.
- macOS 15 may periodically ask again whether the launcher can keep recording the screen, because it captures without the system's window picker.
- Recording areas that span two displays always use the slower fallback.
