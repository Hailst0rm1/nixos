"""Convert legacy BloodHound customqueries.json into a BloodHound CE import zip.

CE's Saved Queries -> Import takes a zip of {name, query, description} JSON files.
Usage: python3 bloodhound-queries-to-ce.py <customqueries.json> <out.zip>
"""

import json
import sys
import zipfile

legacy = json.load(open(sys.argv[1]))["queries"]
seen = set()

with zipfile.ZipFile(sys.argv[2], "w", zipfile.ZIP_DEFLATED) as zf:
    for i, q in enumerate(legacy):
        name = f"[{q.get('category', 'Custom')}] {q['name']}"
        while name in seen:  # CE rejects the whole import on a duplicate name
            name += " (2)"
        seen.add(name)

        steps = q["queryList"]
        # Legacy filled `r:{}` with the UI's enabled edge types; CE has no such
        # substitution, so match any edge type instead.
        query = steps[-1]["query"].replace(":{}*", "*")
        description = q.get("category", "")
        if "$result" in query:
            # Legacy multi-step: CE has no node-select prompt, keep the final step.
            description += " | EDIT FIRST: replace $result with the target's name, e.g. 'DOMAIN ADMINS@CORP.LOCAL'"

        zf.writestr(
            f"{i:03d}.json",
            json.dumps({"name": name, "query": query, "description": description}),
        )

    assert len(zf.namelist()) == len(legacy) == len(seen)
