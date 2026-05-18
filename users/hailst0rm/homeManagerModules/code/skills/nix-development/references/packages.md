# Nix Package Development & Overlays

## Package Derivation Patterns

### stdenv.mkDerivation (C/C++/generic)

The foundational builder. Use for compiled software:

```nix
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  openssl,
}:
stdenv.mkDerivation rec {
  pname = "my-package";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "owner";
    repo = "repo";
    rev = "v${version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ openssl ];

  meta = with lib; {
    description = "Short description";
    homepage = "https://github.com/owner/repo";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "my-package";
  };
}
```

**Build phases:** `unpackPhase` -> `patchPhase` -> `configurePhase` -> `buildPhase` -> `installPhase` -> `fixupPhase`

Override specific phases when needed:
```nix
buildPhase = ''
  make PREFIX=$out
'';
installPhase = ''
  mkdir -p $out/bin
  cp mybinary $out/bin/
'';
```

### buildPythonPackage

```nix
{
  lib,
  python3Packages,
  fetchFromGitHub,
}:
python3Packages.buildPythonPackage rec {
  pname = "my-python-pkg";
  version = "1.0.0";
  pyproject = true; # For pyproject.toml-based projects

  src = fetchFromGitHub {
    owner = "owner";
    repo = "repo";
    rev = "v${version}";
    hash = "";
  };

  build-system = with python3Packages; [ setuptools ];

  dependencies = with python3Packages; [
    requests
    click
  ];

  # Optional: disable tests if they need network access
  doCheck = false;

  meta = with lib; {
    description = "Python package";
    homepage = "https://github.com/owner/repo";
    license = licenses.mit;
  };
}
```

### buildNpmPackage (Node.js)

```nix
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "my-npm-pkg";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "owner";
    repo = "repo";
    rev = "v${version}";
    hash = "";
  };

  npmDepsHash = ""; # Get via: nix-prefetch-npm-deps package-lock.json

  # If the package has a build step
  npmBuildScript = "build";

  meta = with lib; {
    description = "Node.js package";
    homepage = "https://github.com/owner/repo";
    license = licenses.mit;
    mainProgram = "my-npm-pkg";
  };
}
```

### buildGoModule

```nix
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "my-go-pkg";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "owner";
    repo = "repo";
    rev = "v${version}";
    hash = "";
  };

  vendorHash = ""; # Set to null if the project vendors dependencies

  meta = with lib; {
    description = "Go package";
    homepage = "https://github.com/owner/repo";
    license = licenses.mit;
    mainProgram = "my-go-pkg";
  };
}
```

### buildRustPackage

```nix
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "my-rust-pkg";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "owner";
    repo = "repo";
    rev = "v${version}";
    hash = "";
  };

  cargoHash = "";

  meta = with lib; {
    description = "Rust package";
    homepage = "https://github.com/owner/repo";
    license = licenses.mit;
    mainProgram = "my-rust-pkg";
  };
}
```

## Fetchers

| Fetcher | Use case | Key args |
|---------|----------|----------|
| `fetchFromGitHub` | GitHub repos | `owner`, `repo`, `rev`, `hash` |
| `fetchFromGitLab` | GitLab repos | `owner`, `repo`, `rev`, `hash` |
| `fetchurl` | Direct URL download | `url`, `hash` |
| `fetchgit` | Any git repo | `url`, `rev`, `hash` |
| `fetchzip` | ZIP/tarball archives | `url`, `hash` |

### Getting Hashes

**Empty hash trick** (most common): Set `hash = "";`, build, and copy the correct hash from the error message.

**CLI tools:**
```bash
nix-prefetch-url <url>                    # For fetchurl
nix-prefetch-git <repo-url>               # For fetchgit
nix-prefetch-url --unpack <tarball-url>    # For fetchzip
nix hash to-sri --type sha256 <hex-hash>  # Convert to SRI format
```

## Overlay Patterns

### Adding a new package

```nix
# overlays/my-package.nix
final: prev: {
  my-package = prev.callPackage ../pkgs/my-package/package.nix {};
}
```

### Overriding an existing package

```nix
final: prev: {
  some-package = prev.some-package.overrideAttrs (old: {
    version = "2.0.0";
    src = prev.fetchFromGitHub { ... };
    # Extend existing phases
    postPatch = (old.postPatch or "") + ''
      substituteInPlace setup.py --replace "old" "new"
    '';
  });
}
```

### Python package override

```nix
final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      my-python-pkg = python-prev.my-python-pkg.overridePythonAttrs (old: {
        # override attrs
      });
    })
  ];
}
```

## Testing Packages

```bash
# Build a package from its file
nix-build -E 'with import <nixpkgs> {}; callPackage ./package.nix {}'

# Test interactively
nix shell -f ./package.nix

# Build from flake (if exposed)
nix build .#packages.x86_64-linux.my-package

# Check if a package is in the binary cache before building
# Use MCP: nix {"action":"cache","query":"package-name"}
```

## Meta Attributes

```nix
meta = with lib; {
  description = "One-line description";
  longDescription = ''
    Multi-line description.
  '';
  homepage = "https://...";
  license = licenses.mit;        # Check: licenses.gpl3Only, licenses.asl20, etc.
  maintainers = [];
  platforms = platforms.linux;    # Or: platforms.all, platforms.unix
  mainProgram = "binary-name";   # The primary executable
};
```

## Using MCP for Package Development

Before packaging, always check if the package already exists:
```
nix {"action":"search","query":"package-name"}
nix {"action":"info","query":"package-name","channel":"unstable"}
```

Check version history to find the right revision:
```
nix_versions {"package":"package-name","version":"1.0"}
```

Search Noogle for builder function signatures:
```
nix {"action":"search","source":"noogle","query":"buildPythonPackage"}
```
