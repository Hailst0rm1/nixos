final: prev: {
  code-server = prev.code-server.overrideAttrs (oldAttrs: rec {
    version = "4.108.0";

    src = prev.fetchFromGitHub {
      owner = "coder";
      repo = "code-server";
      rev = "v${version}";
      fetchSubmodules = true;
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Placeholder, needs to be computed
    };

    # Commit hash for v4.108.0
    # Computed with: git rev-parse v4.108.0
    commit = "9233f0438330450deb48a0b957820b5f0c7f1e91";

    # The yarnCache derivation also needs to be updated
    yarnCache = prev.stdenv.mkDerivation {
      name = "${oldAttrs.pname}-${version}-${prev.stdenv.hostPlatform.system}-yarn-cache";
      inherit src;

      nativeBuildInputs = with prev; [
        yarn.override
        {nodejs = prev.nodejs;}
        git
        cacert
      ];

      buildPhase = ''
        runHook preBuild

        export HOME=$PWD
        export GIT_SSL_CAINFO="${prev.cacert}/etc/ssl/certs/ca-bundle.crt"

        ${prev.yarn.override {nodejs = prev.nodejs;}}/bin/yarn --cwd "./vendor" install --modules-folder modules --ignore-scripts --frozen-lockfile

        ${prev.yarn.override {nodejs = prev.nodejs;}}/bin/yarn config set yarn-offline-mirror $out
        find "$PWD" -name "yarn.lock" -printf "%h\n" | \
          xargs -I {} ${prev.yarn.override {nodejs = prev.nodejs;}}/bin/yarn --cwd {} \
            --frozen-lockfile --ignore-scripts --ignore-platform \
            --ignore-engines --no-progress --non-interactive

        find ./lib/vscode -name "yarn.lock" -printf "%h\n" | \
          xargs -I {} ${prev.yarn.override {nodejs = prev.nodejs;}}/bin/yarn --cwd {} \
            --ignore-scripts --ignore-engines

        runHook postBuild
      '';

      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
      outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Placeholder, needs to be computed
    };

    # Update the commit in the patch substitutions
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
