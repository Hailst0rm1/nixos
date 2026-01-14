{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "donut";
  version = "1.1";

  src = fetchFromGitHub {
    owner = "TheWover";
    repo = "donut";
    rev = "v${version}";
    hash = "sha256-gKa7ngq2+r4EYRdwH9AWnJodJjCdppzKch4Ve/4ZPhk=";
  };

  # The project includes a pre-compiled static library (aplib64.a)
  # We'll use it as-is since rebuilding it isn't straightforward
  dontStrip = true;

  buildPhase = ''
    runHook preBuild

    # Build the donut executable
    gcc -Wunused-function -Wall -fpack-struct=8 -DDONUT_EXE \
      -I include donut.c hash.c encrypt.c format.c loader/clib.c \
      lib/aplib64.a -o donut

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m755 donut $out/bin/donut

    runHook postInstall
  '';

  meta = with lib; {
    description = "Position-independent code for in-memory execution of VBS/JS/EXE/DLL files and .NET assemblies";
    longDescription = ''
      Donut is a shellcode generator that creates position-independent code enabling
      in-memory execution of VBScript, JScript, EXE, DLL files and .NET assemblies.

      Features include:
      - Compression with aPLib and LZNT1/Xpress/Xpress Huffman
      - 128-bit symmetric encryption using Chaskey cipher
      - AMSI, WLDP, and ETW patching
      - Support for .NET assemblies and unmanaged PE files
      - Multiple output formats (C, Ruby, Python, PowerShell, Base64, etc.)

      Intended for authorized Red Team and penetration testing engagements only.
    '';
    homepage = "https://github.com/TheWover/donut";
    license = licenses.bsd3;
    maintainers = [];
    platforms = platforms.linux;
  };
}
