#!/usr/bin/env python3
"""Extra system metrics for SysMonPanel.qml, as one JSON blob on stdout.

Upstream's watchers/sys_fetcher.sh already covers CPU / RAM / temp / net / disk
and SysData.qml parses it; this covers only what that script does not have —
GPU, ZRAM and the process table. Kept separate rather than bolted onto
sys_fetcher.sh because sys_fetcher runs on a 2s poll for the always-visible bar
pills, while this one only runs while the monitor panel is actually open.

Everything degrades to a present=False block rather than raising, so the panel
renders on a machine with no NVIDIA card and no zram device.
"""

import json
import os
import shutil
import subprocess
import sys

PROC_LIMIT = 40


def run(cmd, timeout=4):
    """Return stdout, or None if the binary is missing / fails / hangs."""
    try:
        out = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, check=False
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    return out.stdout


def gpu():
    """NVIDIA via nvidia-smi, else AMD via sysfs. Intel has neither sysfs
    counter nor a root-free CLI (intel_gpu_top needs CAP_PERFMON), so an
    Intel-only box reports present=False and the panel hides the ring."""
    if shutil.which("nvidia-smi"):
        out = run([
            "nvidia-smi",
            "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits",
        ])
        if out and out.strip():
            # Multi-GPU: first line only. Both hosts here are single-dGPU.
            parts = [p.strip() for p in out.strip().splitlines()[0].split(",")]
            if len(parts) >= 4:
                try:
                    return {
                        "present": True,
                        "vendor": "nvidia",
                        "pct": int(float(parts[0])),
                        "temp": int(float(parts[1])),
                        "memUsed": int(float(parts[2])),
                        "memTotal": int(float(parts[3])),
                    }
                except ValueError:
                    pass

    # amdgpu exposes a busy percentage directly; VRAM is in bytes.
    for card in sorted(os.listdir("/sys/class/drm")) if os.path.isdir("/sys/class/drm") else []:
        base = f"/sys/class/drm/{card}/device"
        busy = f"{base}/gpu_busy_percent"
        if not os.path.exists(busy):
            continue
        try:
            with open(busy) as f:
                pct = int(f.read().strip())
            used = total = 0
            for name, target in (("mem_info_vram_used", "used"), ("mem_info_vram_total", "total")):
                path = f"{base}/{name}"
                if os.path.exists(path):
                    with open(path) as f:
                        val = int(f.read().strip()) // (1024 * 1024)
                    if target == "used":
                        used = val
                    else:
                        total = val
            temp = 0
            hwmon = f"{base}/hwmon"
            if os.path.isdir(hwmon):
                for h in os.listdir(hwmon):
                    tpath = f"{hwmon}/{h}/temp1_input"
                    if os.path.exists(tpath):
                        with open(tpath) as f:
                            temp = int(f.read().strip()) // 1000
                        break
            return {
                "present": True,
                "vendor": "amd",
                "pct": pct,
                "temp": temp,
                "memUsed": used,
                "memTotal": total,
            }
        except (OSError, ValueError):
            continue

    return {"present": False, "vendor": "", "pct": 0, "temp": 0, "memUsed": 0, "memTotal": 0}


def meminfo():
    vals = {}
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                key, _, rest = line.partition(":")
                vals[key] = int(rest.strip().split()[0])  # kB
    except (OSError, ValueError, IndexError):
        pass
    return vals


def zram(mem):
    """zram devices if any exist, otherwise the ring falls back to reporting
    plain swap so it still shows something true on a host without zram.
    `mode` tells the panel which label to draw."""
    if shutil.which("zramctl"):
        out = run(["zramctl", "--raw", "--noheadings", "--bytes",
                   "-o", "NAME,DISKSIZE,DATA,COMPR,TOTAL"])
        if out and out.strip():
            data = compr = disksize = 0
            for line in out.strip().splitlines():
                parts = line.split()
                if len(parts) < 5:
                    continue
                try:
                    disksize += int(parts[1])
                    data += int(parts[2])
                    compr += int(parts[3])
                except ValueError:
                    continue
            if disksize > 0:
                return {
                    "present": True,
                    "mode": "zram",
                    # Percent of the zram device that is filled with data.
                    "pct": int(100 * data / disksize),
                    "usedMb": data // (1024 * 1024),
                    "totalMb": disksize // (1024 * 1024),
                    # How well it is packing: >1 means real memory was saved.
                    "ratio": round(data / compr, 2) if compr else 0.0,
                }

    total = mem.get("SwapTotal", 0)
    free = mem.get("SwapFree", 0)
    used = max(0, total - free)
    return {
        "present": total > 0,
        "mode": "swap",
        "pct": int(100 * used / total) if total else 0,
        "usedMb": used // 1024,
        "totalMb": total // 1024,
        "ratio": 0.0,
    }


# Nix wraps binaries, so the kernel's comm reads ".firefox-wrapped" rather than
# "firefox". comm is also capped at 15 characters, which truncates the suffix
# mid-word — the real values seen here are ".quickshell-wra" and
# ".Hyprland-wrapp" — so matching the whole suffix is not enough; any leading
# slice of it has to go too. Undoing this is what lets DesktopEntries find an
# icon for the row.
WRAPPER_SUFFIXES = ("wrapped", "unwrapped")


def clean_name(comm):
    name = comm
    if name.startswith("."):
        name = name[1:]
    head, sep, tail = name.rpartition("-")
    if sep and head and any(s.startswith(tail) for s in WRAPPER_SUFFIXES):
        name = head
    return name or comm


def _read_proc_table():
    """One pass over /proc/<pid>/stat. Cheaper than `ps -eo pid,pcpu,rss,comm`,
    which costs ~0.9s on a host with 17k processes because it formats every row
    before sorting; this reads the single file that already carries all four
    fields. Returns {pid: (comm, jiffies, rss_pages)}."""
    table = {}
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        try:
            with open(f"/proc/{entry}/stat") as f:
                raw = f.read()
        except OSError:
            continue  # process exited between listdir and open
        # comm sits in parentheses and may itself contain spaces or ')',
        # so split on the LAST ')' rather than on whitespace.
        head, sep, tail = raw.rpartition(")")
        if not sep:
            continue
        open_paren = head.find("(")
        if open_paren < 0:
            continue
        comm = head[open_paren + 1:]
        fields = tail.split()
        # tail starts at field 3 (state), so utime/stime (14,15) are index 11,12
        # and rss (24) is index 21.
        if len(fields) < 22:
            continue
        try:
            jiffies = int(fields[11]) + int(fields[12])
            rss_pages = int(fields[21])
        except ValueError:
            continue
        table[int(entry)] = (comm, jiffies, rss_pages)
    return table


def processes(cache_dir):
    """Top processes by CPU, measured as a delta against the previous poll.

    A single /proc read can only give CPU averaged over the process's whole
    lifetime, which makes a process that was busy an hour ago sit at the top
    forever. Caching the last sample turns that into true instantaneous usage.
    The first poll after the panel opens has no previous sample, so it falls
    back to the lifetime average rather than showing a screen of zeroes.
    """
    now = _read_proc_table()
    try:
        with open("/proc/uptime") as f:
            uptime = float(f.read().split()[0])
    except (OSError, ValueError, IndexError):
        uptime = 0.0

    hz = os.sysconf("SC_CLK_TCK") or 100
    page_kb = (os.sysconf("SC_PAGE_SIZE") or 4096) // 1024

    prev = {}
    prev_uptime = 0.0
    cache_path = os.path.join(cache_dir, "proc_sample.json")
    try:
        with open(cache_path) as f:
            cached = json.load(f)
        prev_uptime = cached.get("uptime", 0.0)
        prev = {int(k): v for k, v in cached.get("procs", {}).items()}
    except (OSError, ValueError, TypeError):
        pass

    elapsed = uptime - prev_uptime
    # A stale cache (panel reopened much later) would divide a huge jiffy delta
    # by a huge elapsed and read as noise; treat anything beyond a minute as no
    # previous sample at all.
    use_delta = 0.2 < elapsed < 60.0

    self_pid = os.getpid()
    rows = []
    for pid, (comm, jiffies, rss_pages) in now.items():
        if pid == self_pid:
            continue
        if use_delta and pid in prev:
            delta = jiffies - prev[pid]
            cpu = (delta / hz) / elapsed * 100.0 if delta > 0 else 0.0
        elif uptime > 0:
            cpu = (jiffies / hz) / uptime * 100.0
        else:
            cpu = 0.0
        rows.append({
            "pid": pid,
            "cpu": round(cpu, 1),
            "rssMb": (rss_pages * page_kb) // 1024,
            "name": clean_name(comm),
        })

    rows.sort(key=lambda r: r["cpu"], reverse=True)

    try:
        os.makedirs(cache_dir, exist_ok=True)
        tmp = cache_path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(
                {"uptime": uptime,
                 "procs": {str(p): v[1] for p, v in now.items()}},
                f, separators=(",", ":"),
            )
        os.replace(tmp, cache_path)
    except OSError:
        pass

    return rows[:PROC_LIMIT]


def vram_processes():
    """Per-process VRAM. NVIDIA only — amdgpu has no equivalent query, and on a
    PRIME-offload laptop this is usually empty because nothing runs on the dGPU."""
    if not shutil.which("nvidia-smi"):
        return []
    out = run([
        "nvidia-smi",
        "--query-compute-apps=pid,used_memory,process_name",
        "--format=csv,noheader,nounits",
    ])
    if not out:
        return []
    rows = []
    for line in out.strip().splitlines():
        parts = [p.strip() for p in line.split(",")]
        if len(parts) < 3:
            continue
        try:
            pid = int(parts[0])
            mb = int(float(parts[1]))
        except ValueError:
            continue
        rows.append({
            "pid": pid,
            "cpu": 0.0,
            "rssMb": mb,
            "name": clean_name(os.path.basename(parts[2])),
        })
    rows.sort(key=lambda r: r["rssMb"], reverse=True)
    return rows


def main():
    # Matches how SysData.qml passes upstream's sysdata cache dir to
    # sys_fetcher.sh; the CPU delta sample lives alongside it.
    cache_dir = os.environ.get("QS_CACHE_SYSMON", "/tmp/qs_sysmon")
    mem = meminfo()
    payload = {
        "gpu": gpu(),
        "zram": zram(mem),
        "cached": mem.get("Cached", 0) // 1024,
        "procs": processes(cache_dir),
        "vram": vram_processes(),
    }
    json.dump(payload, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
