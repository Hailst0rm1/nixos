{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "21st-cli";
  version = "1.6.0";

  # Published only as a bundled npm tarball — package.json has `repository:
  # null` and no GitHub mirror exists, so there is nothing to fetchFromGitHub.
  # The npm URL carries the version, so this pin is honest.
  src = fetchurl {
    url = "https://registry.npmjs.org/@21st-dev/cli/-/cli-${finalAttrs.version}.tgz";
    hash = "sha256-vErEte9UaB0Cisj/nxJslUAdDAJyyngSXau+MVpax34=";
  };

  # `21st install-skill` fetches these three markdown files from 21st.dev at
  # runtime and writes them into ~/.claude/skills — imperative, and invisible
  # to Home Manager. Fetch them at build time instead so they are just files in
  # the store that HM can link.
  #
  # The URLs are UNVERSIONED: upstream edits a skill in place. A fixed hash
  # therefore freezes the content forever (Nix reuses the FOD's cached store
  # path and never re-fetches). `./update.sh` re-prefetches all four hashes —
  # run it to pull upstream edits. Do NOT drop the hashes to "make it dynamic";
  # that is not a thing Nix can do.

  nativeBuildInputs = [makeWrapper];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 dist/index.js "$out/lib/21st/index.js"
    # `21st add` shells out to `npx shadcn@latest add`, so npx must be on PATH.
    makeWrapper ${lib.getExe nodejs} "$out/bin/21st" \
      --add-flags "$out/lib/21st/index.js" \
      --prefix PATH : ${lib.makeBinPath [nodejs]}

    ${lib.concatMapStringsSep "\n" (name: ''
        install -Dm644 ${finalAttrs.passthru.skillSources.${name}} \
          "$out/share/claude-skills/${name}/SKILL.md"
      '')
      finalAttrs.passthru.skillNames}

    runHook postInstall
  '';

  passthru = {
    skillNames = ["21st-cli-use" "21st-registry" "21st-design-sync" "21st-ai"];

    skillSources = {
      "21st-cli-use" = fetchurl {
        url = "https://21st.dev/skills/21st-cli-use.md";
        hash = "sha256-GpjMTQSwhXC5ZyxRcBRaa6AkXHyHbm+dGDIefcWo1os=";
      };
      # 21st-cli-use delegates the generate/iterate flow to this skill.
      "21st-ai" = fetchurl {
        url = "https://21st.dev/skills/21st-ai.md";
        hash = "sha256-vJKK9M2BoJcUthOsFzzZPcWrQuAuTQ0idKl9fyjwNPE=";
      };
      "21st-registry" = fetchurl {
        url = "https://21st.dev/skills/21st-registry.md";
        hash = "sha256-GQsI/2oplb65j6QVWdvIH1XQrJ6nWVgBDQSbGwPkyHY=";
      };
      "21st-design-sync" = fetchurl {
        url = "https://21st.dev/skills/21st-design-sync.md";
        hash = "sha256-ZcyUyELgZvadiRSvPdlJI1RUGLKOH7IwWUc7/1K9D+Q=";
      };
    };
  };

  meta = {
    description = "Search, install and publish 21st.dev components from the terminal";
    homepage = "https://21st.dev/mcp";
    license = lib.licenses.mit;
    mainProgram = "21st";
    platforms = lib.platforms.all;
  };
})
