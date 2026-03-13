{
  lib,
  python3,
  fetchFromGitHub,
}:
python3.pkgs.buildPythonApplication {
  pname = "krbrelayx";
  version = "0-unstable-2026-03-09";
  pyproject = false;

  src = fetchFromGitHub {
    owner = "dirkjanm";
    repo = "krbrelayx";
    rev = "bec37b9417b76acb1d4406932747ebe4a58ed3ce";
    hash = "sha256-Wyg6qWXV1PUNnbSefeyPuFkzDlK1IDbPET380VAU9iU=";
  };

  # Fix Python 3.13 compat: files().iterdir() yields PosixPath, not str
  postPatch = ''
    substituteInPlace lib/clients/__init__.py \
      --replace-fail "for file in clients_dir.iterdir():" "for file in (f.name for f in clients_dir.iterdir()):"
  '';

  propagatedBuildInputs = with python3.pkgs; [
    impacket
    ldap3
    dnspython
  ];

  installPhase = let
    pythonWithDeps = python3.withPackages (ps:
      with ps; [
        impacket
        ldap3
        dnspython
      ]);
  in ''
        runHook preInstall

        mkdir -p $out/lib/krbrelayx
        cp -r *.py lib $out/lib/krbrelayx/

        mkdir -p $out/bin
        for script in krbrelayx addspn dnstool printerbug; do
          cat > $out/bin/$script <<EOF
    #!${pythonWithDeps}/bin/python
    import sys, logging, runpy

    # Fix impacket logger 'identity' KeyError: install a filter that ensures
    # every log record has the 'identity' attribute before formatting
    class _IdentityFix(logging.Filter):
        def filter(self, record):
            if not hasattr(record, 'identity'):
                record.identity = ""
            if not hasattr(record, 'bullet'):
                record.bullet = '[*]'
            return True

    for h in logging.root.handlers:
        h.addFilter(_IdentityFix())

    sys.path.insert(0, "$out/lib/krbrelayx")
    runpy.run_path("$out/lib/krbrelayx/''${script}.py", run_name="__main__")
    EOF
          chmod +x $out/bin/$script
        done

        runHook postInstall
  '';

  doCheck = false;

  meta = with lib; {
    description = "Toolkit for abusing Kerberos (relaying, unconstrained delegation, SPN/DNS manipulation)";
    longDescription = ''
      Krbrelayx is a toolkit for abusing Kerberos, including unconstrained
      delegation abuse and Kerberos relaying. Includes krbrelayx.py (Kerberos
      relay/delegation abuse), addspn.py (SPN management via LDAP), dnstool.py
      (AD-integrated DNS record manipulation), and printerbug.py (SpoolService
      RPC backconnect trigger).

      Intended for authorized penetration testing engagements only.
    '';
    homepage = "https://github.com/dirkjanm/krbrelayx";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux;
    mainProgram = "krbrelayx";
  };
}
