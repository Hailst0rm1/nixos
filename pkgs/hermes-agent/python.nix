# uv2nix virtual-environment builder for hermes-agent.
#
# Replaces the old `pip download` fixed-output derivation. uv2nix reads the
# upstream `uv.lock` (which pins every transitive dependency to an exact
# version + hash) and turns each into an ordinary, individually-hashed
# derivation. Nothing reaches out to PyPI's mutable state at build time, so
# the dependency closure can only change when `uv.lock` itself changes — the
# random hash drift of the old FOD is structurally impossible.
#
# Mirrors upstream nix/python.nix (Linux-only; the aarch64-darwin prebuilt
# overrides are dropped). Pass uv2nix / pyproject-nix / pyproject-build-systems
# from the flake inputs and `src` (the fetched checkout containing uv.lock).
{
  lib,
  python312,
  callPackage,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
  src,
  # Extras to install eagerly. `all` mirrors upstream; `messaging` keeps the
  # telegram/discord/slack backends eager (this config wants them at boot).
  extras ? ["all" "messaging"],
}: let
  workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = src;};

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  # Legacy alibabacloud packages ship only sdists with setup.py/setup.cfg and
  # no pyproject.toml, so setuptools isn't declared as a build dep. (Verbatim
  # from upstream nix/python.nix.)
  buildSystemOverrides = final: prev:
    builtins.mapAttrs
    (name: _:
      prev.${name}.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [final.setuptools];
      }))
    (lib.genAttrs [
      "alibabacloud-credentials-api"
      "alibabacloud-endpoint-util"
      "alibabacloud-gateway-dingtalk"
      "alibabacloud-gateway-spi"
      "alibabacloud-tea"
    ] (_: null));

  # Guard against `response.output` being None in the openai SDK's Responses
  # parser. The venv is sealed (built from the locked wheel) so this can't be
  # done in the install phase like before — patch the package itself instead.
  # `--replace-quiet`: no-op if the locked openai version already fixed it, so
  # a future bump that resolves a patched openai won't break the build.
  pythonPackageOverrides = _final: prev: {
    openai = prev.openai.overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          substituteInPlace "$out/${python312.sitePackages}/openai/lib/_parsing/_responses.py" \
            --replace-quiet \
              'for output in response.output:' \
              'for output in (response.output or []):'
        '';
    });
  };

  pythonSet =
    (callPackage pyproject-nix.build.packages {
      python = python312;
    })
    .overrideScope (lib.composeManyExtensions [
      pyproject-build-systems.overlays.default
      overlay
      buildSystemOverrides
      pythonPackageOverrides
    ]);
in
  pythonSet.mkVirtualEnv "hermes-agent-env" {
    hermes-agent = extras;
  }
