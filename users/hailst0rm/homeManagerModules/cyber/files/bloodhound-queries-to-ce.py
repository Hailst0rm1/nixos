"""Zip bloodhound-queries-ce.json into the archive BloodHound CE's Saved Queries -> Import takes.

CE imports a zip of {name, query, description} JSON files.
Usage: python3 bloodhound-queries-to-ce.py <bloodhound-queries-ce.json> <out.zip>
"""

import json
import sys
import zipfile

queries = json.load(open(sys.argv[1]))
# CE rejects the whole import on a duplicate name, compared case-insensitively.
names = [q["name"].lower() for q in queries]
dupes = {n for n in names if names.count(n) > 1}
assert not dupes, f"duplicate query names: {sorted(dupes)}"

with zipfile.ZipFile(sys.argv[2], "w", zipfile.ZIP_DEFLATED) as zf:
    for i, q in enumerate(queries):
        zf.writestr(f"{i:03d}.json", json.dumps({k: q[k] for k in ("name", "query", "description")}))
