"""Extract recognized NetExec credentials; leave unrecognized output in raw logs."""

import os
from pathlib import Path
import re
import sys


def parse(logs):
    records = set()
    values = {"passwords": set(), "hashes": set(), "aes": set()}
    ansi = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
    prefix = re.compile(r"^(\S+)\s+\S+\s+\d+\s+\S+\s+(.*)$")
    hex32 = r"[0-9a-fA-F]{32}"
    module = ""
    for raw in logs.splitlines():
        line = ansi.sub("", raw).rstrip("\r")
        match = prefix.match(line)
        if match:
            module, line = match.groups()
        elif not re.match(r"^(?:dpapi_(?:machine|user)key:|\S+:\$DCC2\$)", line):
            continue
        # Login banners, progress and errors are never extracted as credentials.
        if re.match(r"^\[(?:\+|\*|-|!)\]", line):
            continue
        kind = value = None
        if match := re.fullmatch(rf"\S+:(?:\d+:)?{hex32}:({hex32}):::(?:.*)?", line):
            kind, value = "hashes", match[1].lower()
        elif match := re.fullmatch(r"\S+:aes(128|256)-cts-hmac-sha1-96:([0-9a-fA-F]+)", line):
            if len(match[2]) != int(match[1]) // 4:
                continue
            kind, value = "aes", match[2].lower()
        elif re.match(r"^(?:dpapi_(?:machine|user)key:0x[0-9a-fA-F]+$|\S+:(?:des-cbc-md5|plain_password_hex):[0-9a-fA-F]+$|\S+:\$DCC2\$)", line):
            pass  # Auxiliary secrets belong in the report, not authentication lists.
        elif match := re.fullmatch(r"GMSA ID:.* NTLM: ([0-9a-fA-F]{32})", line):
            kind, value = "hashes", match[1].lower()
        elif match := re.fullmatch(r"\S+\\[^\s:]+:(.*)", line):
            kind, value = "passwords", match[1]
        elif match := re.fullmatch(r"\S+\\\S+ (.+)", line):
            if module not in {"LSASSY", "HASH_SPIDER"}:
                continue
            value = match[1]
            if re.fullmatch(rf"(?:{hex32}:)?{hex32}", value):
                kind, value = "hashes", value.split(":")[-1].lower()
            else:
                kind = "passwords"
        elif match := re.search(r"(?:^|, | - |On-prem |Entra ID )(?:Password|Passphrase): (.*)$", line):
            kind, value = "passwords", match[1]
        elif module == "REG-WINLOGON" and line.startswith("DefaultPassword: "):
            kind, value = "passwords", line[len("DefaultPassword: "):]
        elif module == "WIFI" and " - Identifier: " in line:
            credential = line.split(" - Identifier: ", 1)[1]
            if ":" not in credential:
                continue
            kind, value = "passwords", credential.split(":", 1)[1]
        elif module in {"MOBAXTERM", "RDCMAN", "SMB"} and line.startswith("["):
            # DPAPI/application credentials: [user][type] [target - ]username:password.
            payload = re.sub(r"^(?:\[[^\]]*\])+\s*", "", line)
            payload = payload.split(" - ", 1)[-1]
            if not (match := re.fullmatch(r"[^\s:]+:(.*)", payload)):
                continue
            kind, value = "passwords", match[1]
        elif re.match(r"^(?:On-prem |Entra ID )?(?:User[Nn]ame|Domain):", line):
            if module not in {"MSOL", "WINSCP", "EVENTLOG_CREDS"}:
                continue
        elif module == "REG-WINLOGON" and re.match(r"^Default(?:UserName|DomainName):", line):
            pass
        else:
            continue
        records.add(line)
        if kind and value and value != "(null)":
            values[kind].add(value)
    return records, values


def main():
    outdir, report, *logs = map(Path, sys.argv[1:])
    records, values = parse("\n".join(path.read_text() for path in logs))
    # These files contain secrets even when the caller has a permissive umask.
    os.umask(0o077)
    report.write_text("".join(line + "\n" for line in sorted(records)))
    report.chmod(0o600)
    for kind, found in values.items():
        path = outdir / (kind + ".txt")
        existing = set(path.read_text().splitlines()) if path.exists() else set()
        # Append only new values, preserving earlier discoveries and password whitespace.
        with path.open("a") as stream:
            if found - existing and path.stat().st_size and not path.read_bytes().endswith(b"\n"):
                stream.write("\n")
            for value in sorted(found - existing):
                stream.write(value + "\n")
        path.chmod(0o600)


if __name__ == "__main__":
    main()
