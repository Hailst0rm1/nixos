{
  lib,
  python3,
  fetchFromGitHub,
}:
python3.pkgs.buildPythonApplication {
  pname = "adpulse";
  version = "1.0.0-unstable-2026-02-27";
  pyproject = false;

  src = fetchFromGitHub {
    owner = "dievus";
    repo = "ADPulse";
    rev = "6baa89b4d9539d50c4bdc2770f937abcc0828a18";
    hash = "sha256-QUoEMbm0gceX431RwIDITMEZF9cpQ5Zk2YUZJ6j+s0Y=";
  };

  propagatedBuildInputs = with python3.pkgs; [
    ldap3
    colorama
    dnspython
    pycryptodome
    weasyprint
  ];

  # No standard build system; install manually
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/adpulse
    cp -r *.py $out/lib/adpulse/

    mkdir -p $out/bin
    cat > $out/bin/adpulse <<EOF
    #!${python3.withPackages (ps: with ps; [ldap3 colorama dnspython pycryptodome weasyprint])}/bin/python
    import sys, os
    sys.path.insert(0, "$out/lib/adpulse")
    os.chdir("$out/lib/adpulse")
    exec(open("$out/lib/adpulse/ADPulse.py").read())
    EOF
    chmod +x $out/bin/adpulse

    runHook postInstall
  '';

  doCheck = false;

  meta = with lib; {
    description = "Active Directory security scanner with 35 automated checks";
    longDescription = ''
      ADPulse connects to a domain controller via LDAP(S), runs 35 automated
      security checks, and produces detailed reports in console, JSON, and HTML
      formats. It operates in read-only mode and is designed for IT administrators,
      penetration testers, and security teams.

      Intended for authorized security assessments only.
    '';
    homepage = "https://github.com/dievus/ADPulse";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux;
    mainProgram = "adpulse";
  };
}
