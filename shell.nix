{pkgs ? import <nixpkgs> {}, ...}: {
  default = pkgs.mkShell {
    nativeBuildInputs = [
      pkgs.pkgsCross.mingwW64.buildPackages.gcc
    ];
  };

  # Msfdb still doesn't work
  metasploit = pkgs.mkShell {
    buildInputs = with pkgs; [
      metasploit
      postgresql
      ruby
      bundler
      libffi
      libxml2
      libxslt
      zlib
    ];

    shellHook = ''
      export PATH=$PATH:${pkgs.postgresql}/bin
      export PGDATA=$HOME/.msf4/db
      export TMPDIR=$HOME/tmp-msf  # workaround for NOEXEC tmp
      mkdir -p "$TMPDIR"
    '';
  };
}
