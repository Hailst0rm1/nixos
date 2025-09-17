{pkgs ? import <nixpkgs> {}, ...}: {
  default = pkgs.mkShell {
    nativeBuildInputs = [
      pkgs.pkgsCross.mingwW64.buildPackages.gcc
    ];
  };

  # Example from Vimenjoyer video
  example = pkgs.mkShell {
    packages = [pkgs.nodejs pkgs.python3];

    # Will import all the dependencies, e.g. rust utils
    inputsFrom = [pkgs.bat];

    shellHook = ''
      echo "welcome to the shell!"
    '';

    # Environment variables
    # Environment variables
    test = "AAAAAA";
    ENVVAR = "testtt";

    LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [pkgs.ncurses]}";

    RUST_BACKTRACE = 1;
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

  python = pkgs.mkShell {
    buildInputs = [
      (pkgs.python3.withPackages (ps:
        with ps; [
          pip
          requests
          numpy
          pandas
          matplotlib
          impacket
          beautifulsoup4
          # add more as you need
        ]))
    ];

    # Optional helpers
    nativeBuildInputs = with pkgs; [
      git
      curl
      wget
      zlib
    ];

    shellHook = ''
      export TMPDIR=/tmp
      export "LD_LIBRARY_PATH=${pkgs.zlib}/lib:$LD_LIBRARY_PATH"
      export VENV_DIR=$(mktemp -d)
      python -m venv $VENV_DIR
      source $VENV_DIR/bin/activate
      echo "Virtual environment is ready and activated in $VENV_DIR."
      pip install pyside2
      echo "🐍 Python dev shell ready!"
      python --version
    '';
  };
}
