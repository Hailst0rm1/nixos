"""Local regression checks: python3 scripts/test-atm-credentials.py."""

import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
PARSER = ROOT / "users/hailst0rm/homeManagerModules/cyber/files/atm-parse-creds.py"
spec = importlib.util.spec_from_file_location("atm_credentials", PARSER)
parser = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parser)


def output(module, text):
    return f"{module:<12} 192.0.2.1 445 HOST {text}\n"


class CredentialsTest(unittest.TestCase):
    def test_formats_and_noise(self):
        nt = "1" * 32
        aes = "2" * 64
        lines = (
            output("SMB", f"alice:500:{'a' * 32}:{nt}:::")
            + output("SMB", f"DOMAIN\\HOST$:aes256-cts-hmac-sha1-96:{aes}")
            + output("SMB", "dpapi_machinekey:0x1234\ndpapi_userkey:0x5678")
            + output("SMB", "DOMAIN\\HOST$:plain_password_hex:abcd")
            + output("SMB", "DOMAIN\\HOST$:des-cbc-md5:0123456789abcdef")
            + output("SMB", "DOMAIN\\service:service password")
            + output("LSASSY", f"DOMAIN\\alice {'a' * 32}:{nt}")
            + output("LSASSY", "DOMAIN\\alice space : colon password  ")
            + output("WINSCP", "Password: winscp:secret")
            + output("MSOL", "On-prem Password: sync password")
            + output("IIS", "Username: pool, Password: pool:password")
            + output("WIFI", "[WPA2PSK] ssid - Passphrase: wifi password")
            + output("WIFI", "[WPA-EAP] ssid - PEAP - Identifier: alice:eap password")
            + output("REG-WINLOGON", "DefaultPassword: autologon password")
            + output("RDCMAN", "[user][profile] server - alice:rdg password")
            + output("MOBAXTERM", "[user] alice:moba password")
            + output("SMB", "[user][CREDENTIAL] target - alice:dpapi password")
            + output("EVENTLOG_CREDS", "Password: event password")
            + output("SMB", "\x1b[1;33mDumping the NTDS, this could take a while\x1b[0m")
            + output("LSASSY", "Saved 21 Kerberos ticket(s) to /tmp/tickets")
            + output("SMB", f"[+] DOMAIN\\alice:{nt} (Pwn3d!)")
            + output("SMB", "[*] No credentials found")
            + output("SMB", "[-] Failed loading module: No module named 'pkg_resources'")
            + "[+] Running: nxc smb host -p input-password\n"
        )
        records, values = parser.parse(lines)
        self.assertEqual(values["hashes"], {nt})
        self.assertEqual(values["aes"], {aes})
        self.assertEqual(values["passwords"], {
            "service password", "space : colon password  ", "winscp:secret",
            "sync password", "pool:password", "wifi password", "eap password",
            "autologon password", "rdg password", "moba password", "dpapi password",
            "event password",
        })
        self.assertIn("dpapi_userkey:0x5678", records)
        self.assertFalse(any("Dumping" in s or "Saved 21" in s or "Pwn3d" in s for s in records))

    def test_cumulative_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log, report = root / "raw.log", root / "parsed.txt"
            log.write_text(output("WINSCP", "Password: new:password"))
            passwords = root / "passwords.txt"
            passwords.write_text("old password")  # Existing file without a final newline.
            command = [sys.executable, str(PARSER), directory, str(report), str(log)]
            subprocess.run(command, check=True)
            subprocess.run(command, check=True)
            self.assertEqual(passwords.read_text(), "old password\nnew:password\n")
            for name in ("passwords.txt", "hashes.txt", "aes.txt", "parsed.txt"):
                self.assertEqual((root / name).stat().st_mode & 0o777, 0o600)
            self.assertEqual((root / "hashes.txt").read_text(), "")
            log.write_text(output("WINSCP", "Password: later password"))
            subprocess.run(command, check=True)
            self.assertEqual(passwords.read_text(), "old password\nnew:password\nlater password\n")

    def test_elevated_with_mock_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            mockbin = root / "bin"
            mockbin.mkdir()
            unbuffer = mockbin / "unbuffer"
            unbuffer.write_text(
                f"#!{sys.executable}\nimport sys\n"
                "if '--sam' in sys.argv:\n"
                f"    print({output('SMB', 'alice:500:' + 'a'*32 + ':' + '1'*32 + ':::')!r})\n"
                "if 'msol' in sys.argv:\n"
                f"    print({output('MSOL', 'On-prem Password: from stderr')!r}, file=sys.stderr)\n"
                "if 'notepad' in sys.argv:\n"
                "    print('mock failure', file=sys.stderr)\n"
                "    sys.exit(7)\n"
            )
            unbuffer.chmod(0o700)
            script = mockbin / "script"
            script.write_text("#!/bin/sh\nexit 0\n")
            script.chmod(0o700)
            source = PARSER.with_name("atm.sh").read_text()
            atm = root / "atm.sh"
            atm.write_text(source.replace("@atm-python@", sys.executable).replace("@atm-parser@", str(PARSER)))
            env = dict(os.environ, PATH=str(mockbin) + os.pathsep + os.environ["PATH"])
            command = ["bash", str(atm), "elevated", "test-host", "-u", "admin", "-H", "a"*32, "-o", str(root), "--local-auth"]
            for _ in range(2):
                subprocess.run(command, env=env, check=True, capture_output=True)
            self.assertEqual((root / "passwords.txt").read_text(), "from stderr\n")
            self.assertEqual((root / "hashes.txt").read_text(), "1"*32 + "\n")
            self.assertIn("On-prem Password: from stderr", (root / "test-host_creds_parsed.txt").read_text())
            self.assertIn("On-prem Password: from stderr", (root / "test-host_interesting.log").read_text())
            self.assertIn("Command exited with status 7", (root / "test-host_interesting.log").read_text())


if __name__ == "__main__":
    unittest.main()
