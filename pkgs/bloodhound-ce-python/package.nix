# CE-native ingestor (BloodHound.py CE build). Same impacket backend as the
# legacy `bloodhound-py` in nixpkgs, so --hashes / Kerberos auth is identical,
# but it emits v6 JSON that BloodHound CE can ingest (legacy emits v5).
{
  lib,
  python3,
  fetchPypi,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "bloodhound-ce";
  version = "1.9.1";
  pyproject = true;

  src = fetchPypi {
    pname = "bloodhound_ce";
    inherit version;
    hash = "sha256-CD3z3DrZmO3P+Ptj/dj1tGSqtf2sjgXMmztlICEPeas=";
  };

  build-system = [python3.pkgs.setuptools];

  dependencies = with python3.pkgs; [
    dnspython
    impacket
    ldap3
    pycryptodome
  ];

  # No upstream tests.
  doCheck = false;
  pythonImportsCheck = ["bloodhound"];

  meta = {
    description = "Python based ingestor for BloodHound Community Edition";
    homepage = "https://github.com/dirkjanm/bloodhound.py";
    license = lib.licenses.mit;
    mainProgram = "bloodhound-ce-python";
  };
}
