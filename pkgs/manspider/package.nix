{
  lib,
  python3,
  fetchFromGitHub,
  fetchPypi,
  autoPatchelfHook,
  stdenv,
}: let
  python = python3;

  # kreuzberg - document intelligence library (pre-built wheel with Rust core)
  kreuzberg = python.pkgs.buildPythonPackage rec {
    pname = "kreuzberg";
    version = "4.3.8";
    format = "wheel";

    src = fetchPypi {
      inherit pname version;
      format = "wheel";
      dist = "cp310";
      python = "cp310";
      abi = "abi3";
      platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
      hash = "sha256-OzN2O9YgVpnvDwuE5fgdbNf5DuTZEFZ9IvQ4nm7JllE=";
    };

    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [stdenv.cc.cc.lib];

    pythonImportsCheck = ["kreuzberg"];

    meta = {
      description = "High-performance document intelligence library for Python";
      homepage = "https://github.com/kreuzberg-dev/kreuzberg";
      license = lib.licenses.mit;
    };
  };
in
  python.pkgs.buildPythonApplication {
    pname = "manspider";
    version = "2.0.0-unstable-2026-02-24";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "blacklanternsecurity";
      repo = "MANSPIDER";
      rev = "0fc8c79f101ff7ecc561fa1f65c1c262a9d0c9d8";
      hash = "sha256-+V8zaIyzYo+iaQAXDQU3Z2HHjAQWen8ajcLLHcetDKU=";
    };

    build-system = [python.pkgs.hatchling];

    dependencies = [
      kreuzberg
      python.pkgs.impacket
      python.pkgs.charset-normalizer
    ];

    pythonImportsCheck = ["man_spider"];

    meta = {
      description = "Spider entire networks for juicy files sitting on SMB shares";
      longDescription = ''
        MANSPIDER is a full-featured SMB spider capable of searching file content
        across entire networks. It supports regex-based filename and content search,
        with text extraction from PDF, DOCX, XLSX, PPTX, images with OCR, and more.

        Intended for authorized penetration testing engagements only.
      '';
      homepage = "https://github.com/blacklanternsecurity/MANSPIDER";
      license = lib.licenses.gpl3;
      maintainers = [];
      platforms = lib.platforms.linux;
      mainProgram = "manspider";
    };
  }
