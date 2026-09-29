# Run 22 — Desktop Service wait at launch

## Why
On a cold launch Storyline's main thread sat in its Desktop Service connect (`RpcClient.ConnectOrWait`) for 13–16 s before it built any UI. That was the largest single block in start-up.

## Where the time goes
Storyline talks to `Articulate 360 Desktop Service.exe` (a .NET Framework 4.8 process) over a named pipe. Lining up Storyline's log with the service's `DesktopService_STABLE_*.log` shows three parts on a cold launch:

1. **Storyline asks late.** It checks whether the service is alive and starts it 3.5–5.6 s after its own process starts, once its host has loaded.
2. **Service cold start.** Under Wine the service's log reaches "Starting RpcServerHost named pipe server" about 3 s after its first line, on top of starting the process itself. Storyline waits 7.5–9 s from "Connecting to named pipe" to "Configuring server factories".
3. **A missing file retried five times.** While setting up the first client connection, the service loads its Review backup queue from `%LOCALAPPDATA%\Articulate\360\ApiCache\v1\7BD91A73`. That file only exists after a Review 360 backup has been queued. The open goes through a helper that retries any failure five times with a fixed 1 s sleep, so the service logs four `OpenStreamWithRetry attempt n/5 failed` warnings and `exhausted all 5 retries` before falling back to an empty queue. That is 4.0–4.3 s on every service start (seven service starts checked), and Storyline waits for it.

A second connection to an already-running service configures in about 6 ms, because the queue is loaded once per service process.

## What can and can't be changed here
- The retry count and interval are constants inside Articulate's code, with no setting. Writing an empty or placeholder file doesn't help: the file is encrypted, and the service deletes an unreadable file as corrupt, so it would be missing again next time. Changing Articulate's binaries is off the table.
- The service keeps running after Storyline quits normally, and the Dock launcher never stops the wineserver, so only the first launch after a login or reboot pays for parts 2 and 3. A warm relaunch connects in about 0.4 s.
- Part 1 is ours to fix: the launcher can start the service itself.

## Change
`tools/launcher/storyline-launcher.sh` starts `Articulate 360 Desktop Service.exe` in the background before it runs Storyline, with no arguments, as Storyline does. The service allows one instance: a second copy started while one is running exits after about 1 s with code 1, writes no log, and leaves the running service alone. Service output goes to `~/StorylineLab/logs/launcher/desktop-service.log`.

## Results
Cold launches (wineserver stopped first), alternating the launcher with and without the new line. Times are from Storyline's process start.

| | Service ready, connect done | Start screen |
|---|---|---|
| Without (2 runs) | 21.3 s / 17.7 s | 52.5 s / 46.2 s |
| With (2 runs) | 13.4 s / 12.0 s | 47.5 s / 39.3 s |

An earlier hand-run pair (service started from a script, same idea) gave 13.0 s vs 20.4 s to connect and 41.8 s vs 52.6 s to the start screen. What remains of the wait with the change is almost all the 4 s missing-file retry plus about 2 s of per-client setup.

Warm relaunch with the new launcher (service already running): connect done at 4.3 s, 0.45 s after "Connecting to named pipe", start screen at 32.1 s. The extra service copy exited on its own and only one service process was left.

## Not done
- Starting the Desktop App as well would make the service pay the retry before Storyline connects, but it opens a window, so the launcher doesn't do it.
- Precompiling the service's assemblies (NGen) could shorten its 3 s cold start; not tried.
