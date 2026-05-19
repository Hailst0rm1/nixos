{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "psobf";
  version = "2.0.1";

  src = fetchFromGitHub {
    owner = "TaurusOmar";
    repo = "psobf";
    rev = "v${version}";
    hash = "sha256-jN0xfAGC+KPpBee+BKBt6n3RHXp12YvDFsBbh4WQUxM=";
  };

  vendorHash = null;

  # Build the main command
  subPackages = ["cmd/psobf"];

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "PowerShell Obfuscator - Transform PowerShell code to hinder analysis and static signatures";
    longDescription = ''
      psobf is a PowerShell obfuscator that supports 5 levels of obfuscation plus a
      transforms/pipeline architecture allowing stacking techniques such as string
      tokenization, light literal encryption, number masking, identifier morphing,
      format jitter, control-flow cosmetics, dead code injection, fragmentation
      profiles, and deterministic profiles.

      Intended for research and authorized Red Team/Pentesting engagements only.
    '';
    homepage = "https://github.com/TaurusOmar/psobf";
    # No license specified in repository - assuming open source for research/educational purposes
    maintainers = [];
    platforms = platforms.unix;
  };
}
