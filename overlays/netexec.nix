final: prev: {
  netexec = prev.netexec.overridePythonAttrs (old: {
    # Fix 1: netexec 1.5.1 passes `signing=` to impacket's LDAPConnection,
    # but the bundled impacket (0.14.0-unstable-2025-12-03) removed that parameter.
    # Patch out the signing kwarg until nixpkgs fixes the version mismatch.
    #
    # Fix 2: check_ldaps_cbt crashes with SysCallError EPIPE when LDAPS is
    # unavailable. Add EPIPE to the handled error list so it falls back gracefully.
    #
    # Fix 3: netexec passes mssql_timeout to impacket's MSSQL.connect(), but
    # impacket 0.14.0 removed the timeout parameter from connect().
    #
    # Fix 4: S4U delegation with ccache: kerberos.py line 24 assigns parseFile
    # result to `tgt` but line 25 checks `my_tgt` (always None), then does a bare
    # `raise` with no active exception → RuntimeError. The except handler in
    # smb.py:424 then calls .getErrorString() on RuntimeError which doesn't exist.
    #
    # Only applies to 1.5.x+ (stable 1.4.0 doesn't have these issues).
    postPatch =
      (old.postPatch or "")
      + final.lib.optionalString (final.lib.versionAtLeast old.version "1.5") ''
        substituteInPlace nxc/protocols/ldap.py \
          --replace-fail "url=ldap_url, baseDN=self.baseDN, dstIp=self.host, signing=False" \
                         "url=ldap_url, baseDN=self.baseDN, dstIp=self.host" \
          --replace-fail "url=ldap_url, baseDN=self.baseDN, dstIp=self.host, signing=self.auth_choice != \"simple\"" \
                         "url=ldap_url, baseDN=self.baseDN, dstIp=self.host" \
          --replace-fail '"ECONNRESET", "WSAECONNRESET", "Unexpected EOF"' \
                         '"ECONNRESET", "WSAECONNRESET", "Unexpected EOF", "EPIPE"'
        substituteInPlace nxc/protocols/mssql.py \
          --replace-fail "self.conn.connect(self.args.mssql_timeout)" \
                         "self.conn.connect()"
        substituteInPlace nxc/protocols/smb/kerberos.py \
          --replace-fail "if my_tgt is None:" \
                         "if tgt is None:"
        # Fix bare `raise` with no active exception context
        sed -i 's/^            raise$/            raise RuntimeError("No TGT found in ccache for S4U delegation")/' \
          nxc/protocols/smb/kerberos.py
        # Fix smb.py exception handler calling .getErrorString() on non-SessionError
        # Only patch the one under `except (SessionError, Exception)` (line ~423-424)
        sed -i '/except (SessionError, Exception) as e:/,+1 s/error, desc = e.getErrorString()/error, desc = e.getErrorString() if hasattr(e, "getErrorString") else (str(e), "")/' \
          nxc/protocols/smb.py
      '';
  });
}
