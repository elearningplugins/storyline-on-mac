#!/usr/bin/env python3
"""Attributes the busiest thread's samples in a macOS `sample` file to modules, naming Wine's Windows modules from a matching `vmmap -wide` file."""
import bisect
import os
import re
import sys
from collections import defaultdict

WAITS = ("read", "mach_msg2_trap", "__ulock_wait2", "semaphore_wait_trap", "__workq_kernreturn", "__select",
         "__psynch_cvwait", "kevent", "__semwait_signal", "swtch_pri", "__recvmsg", "poll")
LINE = re.compile(r"^([ +!:|]*)(\d+) (.*)$")
REGION = re.compile(r"^(.+?)\s+([0-9a-f]+)-([0-9a-f]+)\s+\[.*?\]\s+\S+\s+SM=\S+\s*(.*)$")


def load_regions(path):
    regions = []
    if not path or not os.path.exists(path):
        return regions
    for line in open(path, errors="replace"):
        m = REGION.match(line.rstrip())
        if not m:
            continue
        kind, start, end, rest = m.group(1).strip(), int(m.group(2), 16), int(m.group(3), 16), m.group(4).strip()
        name = os.path.basename(rest) if "/" in rest else ""
        regions.append((start, end, name or kind))
    regions.sort()
    return regions


def region_name(regions, starts, addr):
    i = bisect.bisect_right(starts, addr) - 1
    if i >= 0 and regions[i][0] <= addr < regions[i][1]:
        name = regions[i][2]
        return name if name.lower().endswith((".dll", ".exe", ".so", ".dylib", ".drv", ".sys")) else f"anonymous {name} (JIT code or heap)"
    return "unmapped"


def parse_threads(path):
    lines = open(path, errors="replace").read().split("\n")
    start = next(i for i, l in enumerate(lines) if l.startswith("Call graph:"))
    end = next((i for i, l in enumerate(lines) if l.startswith("Total number in stack")), len(lines))
    threads, stack = [], []
    for l in lines[start + 1:end]:
        m = LINE.match(l)
        if not m:
            continue
        node = {"depth": len(m.group(1)), "count": int(m.group(2)), "sym": m.group(3).strip(), "children": []}
        if node["sym"].startswith("Thread_"):
            threads.append(node)
            stack = [node]
            continue
        while stack and stack[-1]["depth"] >= node["depth"]:
            stack.pop()
        if stack:
            stack[-1]["children"].append(node)
        stack.append(node)
    return threads


def self_samples(node, path, out):
    own = node["count"] - sum(c["count"] for c in node["children"])
    if own > 0:
        out.append((own, path + [node["sym"]]))
    for c in node["children"]:
        self_samples(c, path + [node["sym"]], out)


def frame_module(sym, regions, starts):
    m = re.search(r"\(in ([^)]+)\)", sym)
    if m and m.group(1) != "<unknown binary>":
        return m.group(1)
    a = re.search(r"\[0x([0-9a-f]+)\]", sym)
    return region_name(regions, starts, int(a.group(1), 16)) if a else sym.split()[0]


def main():
    sample_path = sys.argv[1]
    regions = load_regions(sys.argv[2] if len(sys.argv) > 2 else None)
    starts = [r[0] for r in regions]
    threads = parse_threads(sample_path)
    ranked = []
    for t in threads:
        out = []
        self_samples(t, [], out)
        busy = [(n, p) for n, p in out if not any(p[-1].startswith(w + " ") or p[-1].startswith(w + "$") for w in WAITS)]
        ranked.append((sum(n for n, _ in busy), t, busy))
    ranked.sort(key=lambda r: -r[0])
    print(f"{os.path.basename(sample_path)}: {len(regions)} memory regions loaded")
    for total, t, _ in ranked[:4]:
        print(f"  {total:6d} busy / {t['count']} samples  {t['sym'][:70]}")
    total, t, busy = ranked[0]
    by_leaf, by_any = defaultdict(int), defaultdict(int)
    for n, p in busy:
        by_leaf[frame_module(p[-1], regions, starts)] += n
        for mod in {frame_module(f, regions, starts) for f in p[1:]}:
            by_any[mod] += n
    print(f"\nbusiest thread: where the CPU was (self samples, {total} total)")
    for k, v in sorted(by_leaf.items(), key=lambda kv: -kv[1])[:20]:
        print(f"  {v:6d} {100 * v / total:5.1f}%  {k}")
    print("\nbusiest thread: modules anywhere on the stack (inclusive)")
    for k, v in sorted(by_any.items(), key=lambda kv: -kv[1])[:20]:
        print(f"  {v:6d} {100 * v / total:5.1f}%  {k}")


if __name__ == "__main__":
    main()
