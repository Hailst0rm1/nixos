{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  makeWrapper,
  unzip,
  autoPatchelfHook,
  cmake,
  clang,
  llvm,
  pkgsCross,
  mono,
  python3,
  cowsay,
  donut,
}: let
  mingwGcc = pkgsCross.mingwW64.stdenv.cc;

  # wclang - clang wrapper for mingw-w64 cross-compilation
  wclang = stdenv.mkDerivation {
    pname = "wclang";
    version = "unstable-2023-11-10";

    src = fetchFromGitHub {
      owner = "tpoechtrager";
      repo = "wclang";
      rev = "8bbb475cde107e316142c0d2039886167c54b540";
      hash = "sha256-97XCRzxeftiq7pglX0X+wempq6i3toWyBIlP6/eWUhc=";
    };

    nativeBuildInputs = [cmake makeWrapper mingwGcc];
    buildInputs = [clang llvm];

    cmakeFlags = [
      "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
      "-DCLANG_VERSION=${lib.versions.major clang.version}"
    ];

    postInstall = ''
      # wclang wrappers need clang and mingw-w64 gcc on PATH at runtime
      for f in $out/bin/*-w64-mingw32-*; do
        wrapProgram "$f" \
          --prefix PATH : ${lib.makeBinPath [clang llvm mingwGcc]}
      done 2>/dev/null || true
    '';

    meta = {
      description = "Cross-compile source code for Windows using clang on Linux";
      homepage = "https://github.com/tpoechtrager/wclang";
      license = lib.licenses.mit;
    };
  };

  # sgn - Shikata Ga Nai encoder
  sgn = stdenv.mkDerivation {
    pname = "sgn";
    version = "2.0.1";

    src = fetchurl {
      url = "https://github.com/EgeBalci/sgn/releases/download/v2.0.1/sgn_linux_amd64_2.0.1.zip";
      hash = "sha256-Q86tjya5j60h4uFuDZjakuSWBrNHYWwaXuxcC8xJIFY=";
    };

    nativeBuildInputs = [unzip autoPatchelfHook];

    unpackPhase = ''
      unzip $src
    '';

    installPhase = ''
      mkdir -p $out/bin
      install -m755 sgn $out/bin/sgn
    '';

    meta = {
      description = "Shikata Ga Nai encoder ported to Go with improvements";
      homepage = "https://github.com/EgeBalci/sgn";
      license = lib.licenses.mit;
    };
  };

  # xortool - XOR analysis and encryption tool
  xortool = python3.pkgs.buildPythonApplication {
    pname = "xortool";
    version = "1.1.0";
    pyproject = true;

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/50/a5/bb0d09bb838d02e7b37a3ffb225ca6337f241839993d37c5e4c071209eb4/xortool-1.1.0.tar.gz";
      hash = "sha256-MmaYpIAQB5+UG17SG4U45sWGvI66Rg2XrG0ddkGIvVE=";
    };

    build-system = [python3.pkgs.poetry-core];
    dependencies = [python3.pkgs.docopt];

    meta = {
      description = "A tool to analyze multi-byte XOR cipher";
      homepage = "https://github.com/hellman/xortool";
      license = lib.licenses.mit;
    };
  };

  # inline_syscall - header-only library for inline syscalls
  inline_syscall = fetchFromGitHub {
    owner = "JustasMasiulis";
    repo = "inline_syscall";
    rev = "24238544b510d8f85ca38de3a43bc41fa8cfe380";
    hash = "sha256-+8Hsw4QKenVDaFIs5ffOZOXhSEdw/NuWt95L8HE8FJw=";
  };
in
  stdenv.mkDerivation {
    pname = "pezor";
    version = "3.3.0-unstable-2023-03-15";

    src = fetchFromGitHub {
      owner = "phra";
      repo = "PEzor";
      rev = "b4e5927775de49735e22dc4b352b7e45d750cb15";
      hash = "sha256-9Cpd0ObjP80DudrLHjKt4UlWfuO//2ibzjQ0w7+Z5tw=";
    };

    nativeBuildInputs = [makeWrapper];

    dontBuild = true;

    installPhase = ''
      runHook preInstall

      # Install PEzor source tree
      mkdir -p $out/share/pezor
      cp -r . $out/share/pezor/

      # Install inline_syscall dependency
      mkdir -p $out/share/pezor/deps/inline_syscall
      cp -r ${inline_syscall}/* $out/share/pezor/deps/inline_syscall/

      # Patch inline_syscall: remove Windows-only #include <intrin.h>
      chmod -R +w $out/share/pezor/deps
      grep -v '#include <intrin.h>' $out/share/pezor/deps/inline_syscall/include/in_memory_init.hpp \
        > $out/share/pezor/deps/inline_syscall/include/in_memory_init.hpp.tmp
      mv $out/share/pezor/deps/inline_syscall/include/in_memory_init.hpp.tmp \
        $out/share/pezor/deps/inline_syscall/include/in_memory_init.hpp

      # Install and wrap PEzor script
      mkdir -p $out/bin
      makeWrapper $out/share/pezor/PEzor.sh $out/bin/PEzor \
        --set INSTALL_DIR "$out/share/pezor" \
        --prefix PATH : ${lib.makeBinPath [
        wclang
        sgn
        xortool
        donut
        mono
        cowsay
      ]}

      runHook postInstall
    '';

    # Patch INSTALL_DIR in PEzor.sh to use the Nix store path
    postFixup = ''
      chmod +w $out/share/pezor/PEzor.sh
      substituteInPlace $out/share/pezor/PEzor.sh \
        --replace 'INSTALL_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"' \
                  'INSTALL_DIR="$out/share/pezor"'
    '';

    meta = {
      description = "Open-source shellcode and PE packer with evasion techniques";
      longDescription = ''
        PEzor is a shellcode and PE packer that uses various evasion techniques
        including unhooking, syscalls, anti-debugging, memory fluctuation, and
        XOR encryption. It wraps donut for PE-to-shellcode conversion and uses
        mingw-w64 clang for cross-compilation to Windows targets.

        Supports output formats: EXE, DLL, reflective DLL, service EXE/DLL,
        .NET assemblies, and BOF (Beacon Object Files).

        Intended for authorized Red Team and penetration testing engagements only.
      '';
      homepage = "https://github.com/phra/PEzor";
      license = lib.licenses.gpl3;
      maintainers = [];
      platforms = lib.platforms.linux;
      mainProgram = "PEzor";
    };
  }
