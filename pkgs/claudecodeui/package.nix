{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  python3,
  pkg-config,
  pixman,
  cairo,
  pango,
  giflib,
  libjpeg,
  librsvg,
}:
buildNpmPackage rec {
  pname = "cloudcli-ai-cloudcli";
  version = "1.37.0";

  src = fetchFromGitHub {
    owner = "siteboon";
    repo = "claudecodeui";
    rev = "v${version}";
    hash = "sha256-hsXScQ9npRDXw8zIl6vGBmXuA1fM6sCGXE9HYK6akok=";
  };

  npmDepsHash = "sha256-i3h2CLbk7kANhblbXoQLOKlQUUWD+qzuOT19FQHZ7fo=";

  nativeBuildInputs = [
    python3
    pkg-config
  ];

  buildInputs = [
    pixman
    cairo
    pango
    giflib
    libjpeg
    librsvg
  ];

  # node-pty needs special handling
  npmFlags = ["--ignore-scripts"];

  postInstall = ''
    # Rebuild native addons that need it
    cd $out/lib/node_modules/@cloudcli-ai/cloudcli
    npm rebuild node-pty better-sqlite3 bcrypt 2>/dev/null || true
  '';

  dontNpmBuild = false;

  meta = with lib; {
    description = "Web UI for Claude Code with multi-session support";
    homepage = "https://github.com/siteboon/claudecodeui";
    license = licenses.asl20;
    maintainers = [];
    platforms = platforms.linux;
    mainProgram = "cloudcli";
  };
}
