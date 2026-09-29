#!/usr/bin/env python3
"""Summarises a perf-session.sh directory: caret and typing latency, Direct2D DC render target cost, layered-window load, CPU per process class, and Storyline's own project timings."""
import csv
import glob
import json
import os
import statistics
import sys
from collections import defaultdict
from datetime import datetime


def pct(values, p):
    if not values:
        return None
    values = sorted(values)
    return values[min(len(values) - 1, int(round(p / 100 * (len(values) - 1))))]


def fmt_ms(us):
    return "-" if us is None else f"{us / 1000:.1f}"


def stats_line(name, values_us):
    if not values_us:
        return f"  {name:<14} n=0"
    return (f"  {name:<14} n={len(values_us):<5} median={fmt_ms(statistics.median(values_us))} ms  "
            f"p95={fmt_ms(pct(values_us, 95))} ms  max={fmt_ms(max(values_us))} ms")


def read_session(d):
    info = {}
    for line in open(os.path.join(d, "session.txt")):
        if "=" in line:
            k, v = line.rstrip("\n").split("=", 1)
            info[k] = v
    return info


def read_perf(d):
    events, sync = [], None
    path = os.path.join(d, "wine-perf.log")
    if not os.path.exists(path):
        return events, sync
    for line in open(path, errors="replace"):
        parts = line.split()
        if len(parts) < 6 or parts[0] != "perf":
            continue
        try:
            t_us = int(round(float(parts[1]) * 1e6))
        except ValueError:
            continue
        ev = {"t": t_us, "pid": parts[2], "mod": parts[4], "name": parts[5], "args": parts[6:]}
        for a in parts[6:]:
            if "=" in a:
                k, v = a.split("=", 1)
                ev[k] = v
        if ev["name"] == "sync" and sync is None:
            sync = int(ev["epoch_us"]) - t_us
        events.append(ev)
    return events, sync


def caret_section(events, out, sync, start):
    by_pid = defaultdict(list)
    for e in events:
        by_pid[e["pid"]].append(e)
    frames_pid = max(by_pid, key=lambda p: sum(1 for e in by_pid[p] if e["name"] == "dcrt_frame"), default=None)
    if frames_pid is None:
        out.append("  no events")
        return
    ev = sorted(by_pid[frames_pid], key=lambda e: e["t"])
    frames = [e for e in ev if e["name"] == "dcrt_frame"]
    clicks = [e for e in ev if e["name"] == "input" and e["args"] and e["args"][0] == "mouse_down"]
    keys = [e for e in ev if e["name"] == "input" and e["args"] and e["args"][0] == "key_down"]
    focus = [e for e in ev if e["name"] == "focus"]
    out.append(f"  process {frames_pid}: {len(clicks)} clicks, {len(keys)} key presses, {len(focus)} focus changes, {len(frames)} D2D frames")
    out.append("  per click (ms after mouse down): first focus change -> class, first D2D frame, first frame with caret")
    caret_lat, frame_lat = [], []
    for c in clicks:
        nxt = next((e for e in ev if e["t"] > c["t"] and e["name"] == "input" and e["args"][0] == "mouse_down"), None)
        horizon = min(c["t"] + 10_000_000, nxt["t"] if nxt else c["t"] + 10_000_000)
        f = next((e for e in focus if c["t"] <= e["t"] < horizon), None)
        fr = next((e for e in frames if c["t"] <= e["t"] < horizon), None)
        cr = next((e for e in frames if c["t"] <= e["t"] < horizon and int(e.get("caret", "0")) > 0), None)
        if fr:
            frame_lat.append(fr["t"] - c["t"])
        if cr:
            caret_lat.append(cr["t"] - c["t"])
        focus_txt = f"{fmt_ms(f['t'] - c['t'])} -> {f.get('class', '?')}" if f else "-"
        when = (c["t"] + sync) / 1e6 - start if sync is not None else (c["t"] - ev[0]["t"]) / 1e6
        out.append(f"    click @+{when:7.1f}s  focus {focus_txt:<40} frame {fmt_ms(fr['t'] - c['t']) if fr else '-':>8}  caret {fmt_ms(cr['t'] - c['t']) if cr else '-':>8}")
    out.append(stats_line("click->frame", frame_lat))
    out.append(stats_line("click->caret", caret_lat))
    key_lat = []
    for k in keys:
        fr = next((e for e in frames if k["t"] <= e["t"] < k["t"] + 1_000_000), None)
        if fr:
            key_lat.append(fr["t"] - k["t"])
    out.append(stats_line("key->frame", key_lat))
    caret_frames = [e for e in frames if int(e.get("caret", "0")) > 0]
    if len(caret_frames) > 2:
        gaps = [b["t"] - a["t"] for a, b in zip(caret_frames, caret_frames[1:]) if b["t"] - a["t"] < 5_000_000]
        out.append(stats_line("caret interval", gaps))


def dcrt_section(events, out):
    frames = [e for e in events if e["name"] == "dcrt_frame"]
    if not frames:
        out.append("  no DC render target frames")
        return
    sizes = defaultdict(list)
    for e in frames:
        sizes[(int(e["w"]), int(e["h"]))].append(e)
    for (w, h), fs in sorted(sizes.items(), key=lambda kv: -len(kv[1]))[:6]:
        out.append(f"  target {w}x{h}: {len(fs)} frames")
        for key in ("upload_us", "enddraw_us", "present_us"):
            out.append("  " + stats_line(key.replace("_us", ""), [int(e[key]) for e in fs]))
    total = sum(int(e["upload_us"]) + int(e["enddraw_us"]) for e in frames)
    span = (frames[-1]["t"] - frames[0]["t"]) or 1
    out.append(f"  all targets: {total / 1000:.0f} ms in upload+EndDraw over {span / 1e6:.0f} s ({100 * total / span:.1f}% of one core)")


def ulw_section(events, out):
    ws = [e for e in events if e["name"] == "ulw_window"]
    if not ws:
        out.append("  no UpdateLayeredWindow activity")
        return
    rate = [int(e["n"]) * 1e6 / int(e["span_us"]) for e in ws]
    busy = [int(e["total_us"]) / int(e["span_us"]) * 100 for e in ws]
    copies = sum(int(e["copy"]) for e in ws)
    blends = sum(int(e["blend"]) for e in ws)
    sizes = sorted({f"{e['w']}x{e['h']}" for e in ws})
    out.append(f"  {len(ws)} one-second windows with updates; rate median {statistics.median(rate):.1f}/s max {max(rate):.1f}/s")
    out.append(f"  time inside UpdateLayeredWindow: median {statistics.median(busy):.1f}% max {max(busy):.1f}% of one core")
    out.append(f"  copy path (patch 0006) {copies}, blend path {blends}; window sizes {', '.join(sizes[:5])}")


def cpu_section(d, out, info):
    path = os.path.join(d, "cpu.csv")
    if not os.path.exists(path):
        out.append("  no cpu.csv")
        return
    rows = defaultdict(list)
    for r in csv.reader(open(path)):
        if len(r) == 5:
            rows[(r[1], r[2])].append((int(r[0]), float(r[3]), int(r[4])))
    per_class = defaultdict(lambda: defaultdict(float))
    rss = defaultdict(lambda: defaultdict(int))
    for (cls, pid), samples in rows.items():
        samples.sort()
        for (t0, c0, _), (t1, c1, m1) in zip(samples, samples[1:]):
            if t1 > t0 and c1 >= c0:
                per_class[cls][t1] += (c1 - c0) / (t1 - t0) * 100
            rss[cls][t1] += m1
    out.append(f"  {'class':<16}{'mean %':>8}{'p95 %':>8}{'max %':>8}{'peak RSS MB':>13}")
    for cls in sorted(per_class, key=lambda c: -statistics.mean(per_class[c].values())):
        vals = list(per_class[cls].values())
        out.append(f"  {cls:<16}{statistics.mean(vals):8.1f}{pct(vals, 95):8.1f}{max(vals):8.1f}{max(rss[cls].values()) / 1024:13.0f}")
    with open(os.path.join(d, "cpu-timeline.csv"), "w") as f:
        classes = sorted(per_class)
        times = sorted({t for c in classes for t in per_class[c]})
        start = int(info.get("start_epoch", times[0] if times else 0))
        f.write("seconds," + ",".join(classes) + "\n")
        for t in times:
            f.write(f"{t - start}," + ",".join(f"{per_class[c].get(t, 0):.1f}" for c in classes) + "\n")
    out.append("  per-second timeline: cpu-timeline.csv")


def storyline_section(d, out, info):
    start = int(info.get("start_epoch", 0))
    end = int(info.get("end_epoch", 2**31))
    lines = []
    for f in sorted(glob.glob(os.path.join(d, "Storyline_STABLE*.log"))):
        for line in open(f, errors="replace"):
            try:
                j = json.loads(line)
                t = datetime.fromisoformat(j["@t"][:26].rstrip("Z") + "+00:00").timestamp()
            except (ValueError, KeyError):
                continue
            if start <= t <= end + 5:
                lines.append((t, j))
    lines.sort(key=lambda x: x[0])
    if not lines:
        out.append("  no Storyline log lines in the session window")
        return
    out.append(f"  first Storyline log line {lines[0][0] - start:.1f} s after launch; {len(lines)} lines")
    opened = None
    for t, j in lines:
        mt = j.get("@mt", "")
        if "AbandonProjectJobs" in mt:
            opened = t
        elif "ProjectReadyForBackgroundProcessing" in mt and opened:
            out.append(f"  project load at +{opened - start:.1f} s took {t - opened:.1f} s")
            opened = None
    levels = defaultdict(int)
    for _, j in lines:
        levels[j.get("@l", "Information")] += 1
    out.append("  log levels: " + ", ".join(f"{k} {v}" for k, v in sorted(levels.items())))
    cef = [f for f in glob.glob(os.path.join(d, "Storyline-CEF_*.log"))]
    gpu = sum(1 for f in cef for line in open(f, errors="replace") if "gpu" in line.lower())
    out.append(f"  CEF logs: {len(cef)} file(s), {gpu} GPU-related lines")


def marks_section(d, out, info):
    path = os.path.join(d, "marks.tsv")
    if not os.path.exists(path):
        return
    start = int(info.get("start_epoch", 0))
    out.append("\nMarks")
    for line in open(path):
        t, _, text = line.rstrip("\n").partition("\t")
        out.append(f"  +{float(t) - start:7.1f} s  {text}")


def main():
    d = sys.argv[1]
    info = read_session(d)
    events, sync = read_perf(d)
    out = [f"Session {os.path.basename(d)}  label={info.get('label')}",
           "  env: " + " ".join(k + "=" + v for k, v in info.items() if k not in ("label", "start_epoch", "end_epoch")),
           f"  length {int(info.get('end_epoch', 0)) - int(info.get('start_epoch', 0))} s, {len(events)} Wine perf events"]
    out.append("\nCaret and typing latency")
    caret_section(events, out, sync, int(info.get("start_epoch", 0)))
    out.append("\nDirect2D DC render target (Storyline text panes)")
    dcrt_section(events, out)
    out.append("\nUpdateLayeredWindow (AI writer popup and other layered windows)")
    ulw_section(events, out)
    out.append("\nCPU by process class (100% = one core)")
    cpu_section(d, out, info)
    out.append("\nStoryline's own log")
    storyline_section(d, out, info)
    marks_section(d, out, info)
    for report in sorted(glob.glob(os.path.join(d, "sample-*-report.txt"))):
        out.append(f"\nStack sample after a click ({os.path.basename(report)})")
        out.extend("  " + line for line in open(report).read().rstrip().split("\n"))
    print("\n".join(out))


if __name__ == "__main__":
    main()
