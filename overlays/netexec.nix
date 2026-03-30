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
      '';
  });
}
