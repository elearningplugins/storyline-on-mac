# Run 23 — Storyline opened from the Desktop App gets the launcher's CEF switches

## Why
The Storyline Dock launcher passes three Chromium (CEF) switches: `--disable-gpu` (Run 08), `--in-process-gpu` (Run 16, without it Preview and web panels stay blank) and `--enable-features=NetworkServiceInProcess2` (Run 20). Opening Storyline with the Desktop App's **Open** button bypasses that launcher: the Desktop App starts `C:\Program Files\Articulate\360\Storyline 64-bit\Storyline.exe` with no arguments at all, which `ps` confirmed for a Storyline opened that way.

A launcher script can't reach that launch, and Chromium only takes these switches on the command line; there is no environment variable for them. Windows' own hook for this (Image File Execution Options `Debugger`) isn't implemented in Wine, and its wrapper would have to start Storyline without re-triggering itself.

## Fix: patch 0018
`tools/wine-patches/0018-kernelbase-append-configured-arguments-to-new-processes.patch` changes `CreateProcessInternalW` in `kernelbase.dll`:

- `WINE_APPEND_ARGS="app.exe=--a --b;other.exe=--c"` lists extra arguments per exe name (matched case-insensitively against the new process's file name).
- Each listed argument is appended only if the command line doesn't already contain it as a whole space-separated token, so a launch that already has the switches is unchanged.
- Command lines containing `--type=` (Chromium's own helper processes, which are also `Storyline.exe`) are left alone.
- Without the variable, nothing changes.

`build-ntdll.sh` applies it in the existing kernelbase step after patch 0012 and installs 64- and 32-bit `kernelbase.dll` into the mirror.

The switch list now lives in one file, `tools/launcher/storyline-args.sh`, which `install-launchers.sh` copies into both bundles and both launchers source. The Storyline launcher still passes the switches on its own command line from the same variable, so a Wine build without 0018 keeps working; the patch then adds nothing because they are already there.

## Tests
With `cmd.exe` standing in for Storyline, launched through `start` (which uses `ShellExecuteEx`, like most programs that open another app):

| Case | Result |
|---|---|
| Name matches | `--alpha --beta` appended |
| Argument already present as its own token | not appended again |
| Present only as a prefix (`--alpha-x`) | `--alpha` appended |
| Command line has `--type=gpu` | nothing appended |
| Variable names another exe | nothing appended |
| Variable unset | nothing appended |
| Name in capitals (`CMD.EXE`) | appended |
| Two entries, second matches | only the second entry's arguments appended |
| Direct `wine cmd …` from macOS | appended (so the Dock launcher's own launch also goes through this path) |

End to end: after restarting the Desktop App from the updated Dock launcher and clicking **Open** next to Storyline 360, Storyline's command line was `Storyline.exe --disable-gpu --in-process-gpu --enable-features=NetworkServiceInProcess2`, and its only CEF helper was the storage utility process (no separate GPU process).

## Not covered
- `Articulate360Bridge.app` (the `articulate://` sign-in handler) starts the Desktop App with its own environment. If it is what starts the Desktop App, a Storyline opened from that Desktop App won't get the switches. Normally the Desktop App is already running at sign-in.
- The UI automation couldn't click the Desktop App's WPF buttons (the injected click never registered), so the end-to-end check was one manual click.
