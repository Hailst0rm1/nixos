# vol-wrapper module lists

Curated Volatility 3 plugin lists for `vol-wrapper -m`. Deployed to
`~/cyber/dfir/vol-modules/` when `cyber.dfir.enable = true`.

```sh
vol-wrapper -i mem.raw -m ~/cyber/dfir/vol-modules/windows-triage.txt -o out
# then widen the same output dir; --resume skips what triage already wrote
vol-wrapper -i mem.raw -m ~/cyber/dfir/vol-modules/windows-deep.txt -o out --resume
```

| File | Plugins | What it answers |
| --- | --- | --- |
| `windows-triage.txt` | 32 | The SANS six steps: rogue processes, DLLs/handles, network, injection, rootkit, plus execution and persistence evidence |
| `windows-deep.txt` | 56 | Triage + EDR-evasion checks, hollowing, MFT, timeline, LSA secrets, kernel hook detail |
| `linux-triage.txt` | 18 | Processes three ways, bash history, sockets, open files, syscall hooks, hidden modules, injection |
| `linux-deep.txt` | 38 | Triage + every `linux.malware.*` hook check, ftrace/tracepoints/eBPF, page cache, timeline |
| `mac-triage.txt` | 18 | Processes, network, injection, syscall/sysctl/trap-table hooks |

Each `-deep` list is a superset of its `-triage` list. There is no `mac-deep`:
Volatility has 23 mac plugins, so `-t mac` is the deep run.

## Format

`vol-wrapper` reads one plugin per line and treats every non-blank line as a
plugin name — comments are not supported, which is why the notes live here.
A `-m` list runs in the order written, so each file is sorted slowest first
(Windows from measured runtimes, Linux and mac from upstream's defaults).

## Left out on purpose

Reach these with `-t <os>`, which runs everything.

- **Windows, slow or noisy:** `memmap` (slowest plugin by far), `poolscanner`,
  `bigpools`, `vadwalk`, `thrdscan`, `threads`, `mftscan.ResidentData`,
  `statistics`, `virtmap`, `kpcrs`
- **Windows, niche:** the GUI set (`windows`, `desktops`, `deskscan`,
  `windowstations`), `crashinfo`, `mbrscan`, `debugregisters`, `iat`,
  `verinfo`, `symlinkscan`, `joblinks`, `getservicesids`, `truecrypt`,
  `registry.certificates`, `registry.hivescan`, `registry.printkey` (only
  useful with `--key`), `svclist` (`svcscan` and `svcdiff` cover it)
- **Linux:** `kallsyms`, `pscallstack`, `iomem`, `vmcoreinfo`,
  `graphics.fbdev`, `pagecache.InodePages`; `check_modules` and
  `hidden_modules` are already run by `modxview`
- **mac:** `list_files`, `proc_maps`, `kevents`, `kauth_scopes`, `vfsevents`
- **Need arguments:** `yarascan`, `vadyarascan`, `vmayarascan`, `dumpfiles`,
  `pedump`, `strings` — run them by hand against a PID or rule file once
  triage points somewhere

## When volatility3 updates

Volatility renames plugins (most detections moved under `*.malware.*` and
`windows.registry.*`). The build fails when a listed name no longer exists in
the pinned inventory (see `vol-modules` in `dfir.nix`). A deprecated alias
still runs, so it passes the build; this stricter check flags those too:

```sh
csv=$(dirname "$(readlink -f "$(which vol-wrapper)")")/../share/vol-wrapper/plugins.csv
cat ~/cyber/dfir/vol-modules/*.txt | sort -u | while read -r m; do
  grep -q "^$m,.*,True,[^,]*,False," "$csv" || echo "stale: $m"
done
```
