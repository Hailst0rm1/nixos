final: prev: {
  netexec = prev.netexec.overridePythonAttrs (old: {
    version = "1.5.1";

    src = prev.fetchFromGitHub {
      owner = "Pennyw0rth";
      repo = "NetExec";
      tag = "v1.5.1";
      hash = "sha256-BKqBmpA2cSKwC9zX++Z6yTSDIyr4iZVGC/Eea6zoMLQ=";
    };

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail " @ git+https://github.com/fortra/impacket" "" \
        --replace-fail " @ git+https://github.com/wbond/oscrypto" "" \
        --replace-fail " @ git+https://github.com/Pennyw0rth/NfsClient" "" \
        --replace-fail " @ git+https://github.com/Pennyw0rth/Certipy" ""
    '';
  });
}
