{
  stdenv,
  lib,
  fetchFromGitHub,
  zlib,
  openssl,
  ncurses,
  libidn,
  pcre2,
  libssh,
  libmysqlclient,
  libpq,
  samba,
  freerdp,
  withGUI ? false,
  makeWrapper,
  pkg-config,
  gtk2,
}:
stdenv.mkDerivation rec {
  pname = "thc-hydra";
  version = "9.5+RDP";

  src = fetchFromGitHub {
    owner = "vanhauser-thc";
    repo = "thc-hydra";
    # rev = "v${version}";
    rev = "b763262c4ac5964dd1f9f0fa3ab05c70c0ccfae1";
    sha256 = "sha256-MjAo96wRbVJNsf/+8Ik8nrz4GJxw7ou571RsmIFrTPU=";
    # sha256 = "sha256-gdMxdFrBGVHA1ZBNFW89PBXwACnXTGJ/e/Z5+xVV5F0=";
  };

  postPatch = let
    makeDirs = output: subDir:
      lib.concatStringsSep " " (map (path: lib.getOutput output path + "/" + subDir) buildInputs);
  in ''
    substituteInPlace configure \
      --replace-fail '$LIBDIRS' "${makeDirs "lib" "lib"}" \
      --replace-fail '$INCDIRS' "${makeDirs "dev" "include"}" \
      --replace-fail "/usr/include/math.h" "${lib.getDev stdenv.cc.libc}/include/math.h" \
      --replace-fail "libcurses.so" "libncurses.so" \
      --replace-fail "-lcurses" "-lncurses"
  '';

  nativeBuildInputs = lib.optionals withGUI [
    pkg-config
    makeWrapper
  ];

  buildInputs =
    [
      zlib
      openssl
      ncurses
      libidn
      pcre2
      libssh
      libmysqlclient
      libpq
      samba
      freerdp
    ]
    ++ lib.optional withGUI gtk2;

  enableParallelBuilding = true;

  DATADIR = "/share/${pname}";

  postInstall = lib.optionalString withGUI ''
    wrapProgram $out/bin/xhydra \
      --add-flags --hydra-path --add-flags "$out/bin/hydra"
  '';

  meta = with lib; {
    description = "Very fast network logon cracker which support many different services";
    homepage = "https://github.com/vanhauser-thc/thc-hydra"; # https://www.thc.org/
    changelog = "https://github.com/vanhauser-thc/thc-hydra/raw/v${version}/CHANGES";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [offline];
    platforms = platforms.unix;
  };
}
