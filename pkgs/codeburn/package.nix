{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchurl,
}: let
  litellmPricing = fetchurl {
    url = "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json";
    hash = "sha256-Q7Z0A0QijDSQRHq28RcqgU7k1CorvwbYMDHa1m/OmQA=";
  };
in
  buildNpmPackage rec {
    pname = "codeburn";
    version = "0.9.9";

    src = fetchFromGitHub {
      owner = "getagentseal";
      repo = "codeburn";
      rev = "v0.9.9";
      hash = "sha256-omBrDC5xMlfHjMIHLjUTmq6jFLjmc2BF/TPu+3typUs=";
    };

    npmDepsHash = "sha256-2bkhUZuP3a0ySSmvI/EODegpPzkh7nvOHhyQlBY6m2o=";

    # The build script fetches litellm pricing data from GitHub at build time.
    # Replace it with a version that reads from the pre-fetched local file.
    preBuild = ''
      cp ${litellmPricing} litellm-raw.json
      cat > scripts/bundle-litellm.mjs << 'SCRIPT'
      import { readFileSync, writeFileSync, mkdirSync } from "fs";
      import { dirname, join } from "path";
      import { fileURLToPath } from "url";

      const __dirname = dirname(fileURLToPath(import.meta.url));
      const outPath = join(__dirname, "..", "src", "data", "litellm-snapshot.json");
      const data = JSON.parse(readFileSync(join(__dirname, "..", "litellm-raw.json"), "utf8"));

      const MANUAL_ENTRIES = {
        "MiniMax-M2.7":           [0.3e-6, 1.2e-6, 0.375e-6, 0.06e-6],
        "MiniMax-M2.7-highspeed": [0.6e-6, 2.4e-6, 0.375e-6, 0.06e-6],
      };

      const snapshot = {};
      const entries = Object.entries(data).filter(([k]) => k !== "sample_spec");

      function toVal(entry) {
        const inp = entry.input_cost_per_token;
        const out = entry.output_cost_per_token;
        if (inp == null || out == null) return null;
        return [inp, out, entry.cache_creation_input_token_cost ?? null, entry.cache_read_input_token_cost ?? null];
      }

      for (const [name, entry] of entries) {
        if (name.includes("/")) continue;
        const val = toVal(entry);
        if (val) snapshot[name] = val;
      }

      for (const [name, entry] of entries) {
        if (!name.includes("/")) continue;
        const val = toVal(entry);
        if (!val) continue;
        if (!snapshot[name]) snapshot[name] = val;
        const stripped = name.replace(/^[^/]+\//, "");
        if (stripped !== name && !snapshot[stripped]) snapshot[stripped] = val;
      }

      Object.assign(snapshot, MANUAL_ENTRIES);
      mkdirSync(dirname(outPath), { recursive: true });
      writeFileSync(outPath, JSON.stringify(snapshot));
      SCRIPT
    '';

    meta = with lib; {
      description = "Interactive TUI dashboard for tracking AI coding tool token usage and costs";
      homepage = "https://github.com/getagentseal/codeburn";
      license = licenses.asl20;
      maintainers = [];
      platforms = platforms.linux;
      mainProgram = "codeburn";
    };
  }
