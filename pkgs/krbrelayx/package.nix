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
    import sys, os
    sys.path.insert(0, "$out/lib/krbrelayx")
    exec(open("$out/lib/krbrelayx/''${script}.py").read())
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
