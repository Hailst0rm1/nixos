{
  lib,
  python3,
  fetchFromGitHub,
  fetchPypi,
}: let
  python = python3;

  asysocks = python.pkgs.asysocks.overridePythonAttrs (old: rec {
    version = "0.2.18";
    src = fetchPypi {
      pname = "asysocks";
      inherit version;
      hash = "sha256-zGGW6CyK3Is84jId3fY1UAx2AxbaS3zKMhtTLLs9/fU=";
    };
  });

  kerbad = (python.pkgs.kerbad.override {inherit asysocks;}).overridePythonAttrs (old: rec {
    version = "0.5.12";
    src = fetchPypi {
      pname = "kerbad";
      inherit version;
      hash = "sha256-mD35zFBCpdZg9DENnhVc7SWvu6GjZf/NCQP8UMRwhQI=";
    };
    # kerbad 0.5.10 dropped minikerberos dependency
    dependencies = with python.pkgs; [
      asn1crypto
      asysocks
      cryptography
      dnspython
      six
      tqdm
      unicrypto
    ];
    pythonImportsCheck = ["kerbad"];
  });

  badauth = (python.pkgs.badauth.override {inherit asysocks kerbad;}).overridePythonAttrs (old: rec {
    version = "0.1.7";
    src = fetchPypi {
      pname = "badauth";
      inherit version;
      hash = "sha256-kv+U0sUveJsSrLondCpVy/G+EAVnTEl/rGC7Z27qCKc=";
    };
  });

  unidns = python.pkgs.unidns.override {inherit asysocks;};

  badldap = (python.pkgs.badldap.override {inherit asysocks badauth kerbad unidns;}).overridePythonAttrs (old: rec {
    version = "0.7.7";
    src = fetchPypi {
      pname = "badldap";
      inherit version;
      hash = "sha256-goDMe+P72KvUjTRGnb2BWN6ECfrfFy48MTjU4zdwa40=";
    };
  });
in
  python.pkgs.buildPythonApplication {
    pname = "bloodyAD";
    version = "2.5.7";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "CravateRouge";
      repo = "bloodyAD";
      rev = "v2.5.7";
      hash = "sha256-Z/yvjraALxhodCFQtLPmyXEz0qT3BBC7Nq5Qlv2OM2s=";
    };

    build-system = [python.pkgs.hatchling];

    pythonRelaxDeps = ["cryptography"];

    dependencies = [
      python.pkgs.cryptography
      badldap
      python.pkgs.winacl
      python.pkgs.asn1crypto
      kerbad
    ];

    pythonImportsCheck = ["bloodyAD"];

    meta = {
      description = "AD Privesc Swiss Army Knife";
      homepage = "https://github.com/CravateRouge/bloodyAD";
      license = lib.licenses.mit;
      maintainers = [];
      platforms = lib.platforms.linux;
      mainProgram = "bloodyAD";
    };
  }
