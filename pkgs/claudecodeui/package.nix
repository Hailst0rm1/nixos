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
  version = "1.37.4";

  src = fetchFromGitHub {
    owner = "siteboon";
    repo = "claudecodeui";
    rev = "v${version}";
    hash = "sha256-0qXu4cc+PBGPF14toavunWeyy/Yk0Z9hYZyDjtkSZWI=";
  };

  npmDepsHash = "sha256-Qrv5xlLgY8cpHqmYOz3WMqHO4rj/9BIXqJ7Up3lQ2GU=";

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
