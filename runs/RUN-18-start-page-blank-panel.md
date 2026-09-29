# Run 18 — Start screen: the right-hand web panel stays blank

## Symptom
On Windows, Storyline's start screen shows Articulate's web content on the right (a welcome or what's-new page). Under Wine the area stays white. The left-hand links (New Project, Record Screen, recent files) work.

## What the panel is
It is not Chromium. Articulate's `StartPage` control (in `Articulate.Windows.Forms`) hosts a `System.Windows.Forms.WebBrowser`, which is the IE ActiveX control. Under Wine that means `ieframe` + `mshtml` rendering with Wine Gecko (2.47.4, installed in the prefix). No CEF process is involved.

The control starts with `Visible = false` and navigates to `https://ipc.articulate.com/slw/360/en/startpage/`, which redirects to `https://cdn.articulate.com/assets/start-screens/i18n/storyline.html`. It becomes visible only in its `ProgressChanged` handler, when `CurrentProgress == MaximumProgress`. It is not shown on `DocumentCompleted` or `Navigated`.

## Cause
Wine's `ieframe` never fires `DISPID_PROGRESSCHANGE`. Its own conformance tests mark that as missing (`todo_wine CHECK_CALLED(Invoke_PROGRESSCHANGE)` in `dlls/ieframe/tests/webbrowser.c`). So the page loads but the control is never shown.

A second detail is why the event has to come from the download rather than from `DocumentComplete`. While the first load is still running, Storyline calls `WebBrowser.Refresh()` (seen in an `ieframe` trace). As in IE, a refresh ends without `DocumentComplete` (mshtml skips `FireDocumentComplete` for `BINDING_REFRESH`), but it still reaches download-complete. A first attempt that fired `ProgressChange` next to `DocumentComplete` worked in a test app and still left Storyline blank.

## Fix: patch 0015
`tools/wine-patches/0015-ieframe-fire-ProgressChange-when-a-download-completes.patch`: `notify_download_state` fires `ProgressChange(10000, 10000)` just before `DownloadComplete`, except for `about:` pages, where IE doesn't fire it either (Wine's tests expect none there). `build-ntdll.sh` applies it and installs 64- and 32-bit `ieframe.dll`. `vmmap` shows Storyline loading `ieframe.dll` from the patched Wine tree.

## Verified
- `tools/probes/wbprogress` (hidden `WebBrowser`, like Storyline's) on Articulate's start page URL. Stock: `Navigating`, `Navigated` and `DocumentCompleted` fire, with no `ProgressChanged`. Patched: `ProgressChanged 10000/10000` fires before `Navigated` and again before `DocumentCompleted`. For `about:blank` there is still no `ProgressChanged`.
- Storyline restarted on the patched build: the start screen shows the "Welcome to Storyline 360" page on the right, and a `Shell Embedding` window appears in the window tree (none before).
- Wine's `ieframe` `webbrowser` conformance test, built standalone and run on stock and patched `ieframe.dll`. Stock: 18429 tests, 347 todo, 0 failures. Patched: 18493 tests, 339 todo, 8 "failures", all `webbrowser.c:3151: Test succeeded inside todo block: expected Invoke_PROGRESSCHANGE`. Those are expectations Wine marked as not yet met, now met. There are no unexpected calls.

## Not verified
- What the page looks like signed in: the Windows screenshot showed different content ("Working with triggers is easier than ever"), which is what Articulate's server returns for that account and session, not something this patch controls.
- Real IE fires `ProgressChange` repeatedly with byte counts during a load. Wine now fires only the final "complete" value, which is what hosts that wait for completion need; a progress bar would jump straight to full.
