{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchurl,
}: let
  # Pinned to a litellm release tag instead of `main`. Pinning to `main`
  # causes Nix to silently keep the cached file forever — new prices on
  # upstream's main branch never reach this derivation until the hash
  # changes. Bump `litellmRelease` to a newer https://github.com/BerriAI/litellm
  # release tag and refresh the hash to pick up new model prices.
  litellmRelease = "v1.86.2";
  litellmPricing = fetchurl {
    url = "https://raw.githubusercontent.com/BerriAI/litellm/refs/tags/${litellmRelease}/model_prices_and_context_window.json";
    hash = "sha256-Q7Z0A0QijDSQRHq28RcqgU7k1CorvwbYMDHa1m/OmQA=";
  };
in
  buildNpmPackage rec {
    pname = "codeburn";
    version = "0.9.13";

    src = fetchFromGitHub {
      owner = "getagentseal";
      repo = "codeburn";
      # Upstream publishes parallel `v0.9.X` and `mac-v0.9.X` tag series that
      # point at identical commits; 0.9.13 only has the `mac-` tag so far.
      rev = "mac-v0.9.13";
      hash = "sha256-z/67n+HWuPH/jrydyG3yM9b0v8puiOZQjKndBJXFf1o=";
    };

    npmDepsHash = "sha256-DlGIFGpYybDQWppj+L9Xb7fhIs4SLuX95a684Grd/oY=";

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
