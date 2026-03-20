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
    version = "0.5.10";
    src = fetchPypi {
      pname = "kerbad";
      inherit version;
      hash = "sha256-qSJgJ1TxOaQo94YhgXEhO1BTnz/kviRxTRhmdDHkzw0=";
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
    version = "0.1.6";
    src = fetchPypi {
      pname = "badauth";
      inherit version;
      hash = "sha256-MqZPcFVjI4qkPLCP3uwaT6FcpnQMdtIFI9AqnYeTll4=";
    };
  });

  unidns = python.pkgs.unidns.override {inherit asysocks;};

  badldap = (python.pkgs.badldap.override {inherit asysocks badauth kerbad unidns;}).overridePythonAttrs (old: rec {
    version = "0.7.5";
    src = fetchPypi {
      pname = "badldap";
      inherit version;
      hash = "sha256-8cWO1rQJhBgN0DmOfNxzXaCvfX5W2n55QsUFYXoz1wQ=";
    };
  });
in
  python.pkgs.buildPythonApplication {
    pname = "bloodyAD";
    version = "2.5.4";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "CravateRouge";
      repo = "bloodyAD";
      rev = "v2.5.4";
      hash = "sha256-6ZSJTupjVhvyU9G/eePJiXk16w9HwpsOFwdwTSLb7tU=";
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
