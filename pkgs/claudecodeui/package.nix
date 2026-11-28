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
  version = "1.37.11";

  src = fetchFromGitHub {
    owner = "siteboon";
    repo = "claudecodeui";
    rev = "v${version}";
    hash = "sha256-FlsrM9OQFdSsHS461S73tpkyIX8jPXQrxCLnMDiEFU8=";
  };

  npmDepsHash = "sha256-IYGY9OM2VEA6k8heSCs7vUU2XDKvFaMnaG72S9/lvlg=";

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
