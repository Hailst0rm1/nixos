{
  lib,
  stdenv,
  makeWrapper,
  bash,
  systemd,
  nix,
}:
stdenv.mkDerivation {
  pname = "aws-cvpn-wrapper";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    mkdir -p $out/bin
    cp aws-cvpn-wrapper.sh $out/bin/aws-cvpn-wrapper
    chmod +x $out/bin/aws-cvpn-wrapper

    wrapProgram $out/bin/aws-cvpn-wrapper \
      --prefix PATH : ${lib.makeBinPath [bash systemd nix]}
  '';

  meta = with lib; {
    description = "Wrapper for AWS CVPN client with automatic DNS configuration";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "aws-cvpn-wrapper";
  };
}
