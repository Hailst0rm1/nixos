final: prev: {
  code-server = prev.code-server.overrideAttrs (oldAttrs: rec {
    version = "4.108.0";
    commit = "9233f0438330450deb48a0b957820b5f0c7f1e91";

    src = prev.fetchFromGitHub {
      owner = "coder";
      repo = "code-server";
      rev = "v${version}";
      fetchSubmodules = true;
      hash = "sha256-Jpu7ITmC/5pxHpYPF7oZpa8HkgLMFId8HIoDAJYFV0Y=";
    };

    # Update the yarn cache for the new version
    yarnCache = prev.stdenv.mkDerivation {
      name = "code-server-${version}-${prev.stdenv.hostPlatform.system}-yarn-cache";
      inherit src;

      nativeBuildInputs = with prev; [
        (yarn.override {nodejs = oldAttrs.nodejs or prev.nodejs;})
        git
        cacert
      ];

      buildPhase = ''
        runHook preBuild

        export HOME=$PWD
        export GIT_SSL_CAINFO="${prev.cacert}/etc/ssl/certs/ca-bundle.crt"

        yarn --cwd "./vendor" install --modules-folder modules --ignore-scripts --frozen-lockfile

        yarn config set yarn-offline-mirror $out
        find "$PWD" -name "yarn.lock" -printf "%h\n" | \
          xargs -I {} yarn --cwd {} \
            --frozen-lockfile --ignore-scripts --ignore-platform \
            --ignore-engines --no-progress --non-interactive

        find ./lib/vscode -name "yarn.lock" -printf "%h\n" | \
          xargs -I {} yarn --cwd {} \
            --ignore-scripts --ignore-engines

        runHook postBuild
      '';

      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
      outputHash = prev.lib.fakeSha256; # Will need to be updated after first build
    };

    postPatch = ''
      export HOME=$PWD

      patchShebangs ./ci

      # inject git commit
      substituteInPlace ./ci/build/build-vscode.sh \
        --replace-fail '$(git rev-parse HEAD)' "${commit}"
      substituteInPlace ./ci/build/build-release.sh \
        --replace-fail '$(git rev-parse HEAD)' "${commit}"
    '';
  });
}
