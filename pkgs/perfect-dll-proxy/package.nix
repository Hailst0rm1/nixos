{
  lib,
  fetchFromGitHub,
  python3Packages,
}:
python3Packages.buildPythonApplication {
  pname = "perfect-dll-proxy";
  version = "1.0.0";

  # Fetch from GitHub
  src = fetchFromGitHub {
    owner = "mrexodia";
    repo = "perfect-dll-proxy";
    rev = "c6dce641619c63e2af51231f4cf8c330d32547f7"; # Latest commit as of Nov 2025
    sha256 = "sha256-T2TFD45odVsoigWw7XR2Y0Xc1UcVnwbfS0f/5p7ciJA=";
  };

  format = "other";

  propagatedBuildInputs = with python3Packages; [
    pefile
  ];

  doCheck = false; # No tests provided upstream

  installPhase = ''
    runHook preInstall

    # Create installation directories
    mkdir -p $out/bin
    mkdir -p $out/lib/perfect-dll-proxy

    # Copy the main script
    cp perfect-dll-proxy.py $out/lib/perfect-dll-proxy/

    # Create wrapper script
    cat > $out/bin/perfect-dll-proxy <<EOF
    #!${python3Packages.python.interpreter}
    import sys
    sys.path.insert(0, "$out/lib/perfect-dll-proxy")
    exec(open("$out/lib/perfect-dll-proxy/perfect-dll-proxy.py").read())
    EOF

    chmod +x $out/bin/perfect-dll-proxy

    runHook postInstall
  '';

  meta = with lib; {
    description = "Generate proxy DLLs for DLL hijacking using absolute path forwarding";
    homepage = "https://github.com/mrexodia/perfect-dll-proxy";
    license = licenses.boost;
    maintainers = [];
    platforms = platforms.all;
  };
}
