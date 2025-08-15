{
  lib,
  fetchFromGitHub,
  python3Packages,
}:
python3Packages.buildPythonApplication rec {
  pname = "ipcrawler";
  version = "unstable-2025-08-13";

  src = fetchFromGitHub {
    owner = "neur0map";
    repo = "ipcrawler";
    rev = "main"; # replace with pinned commit sha for reproducibility
    hash = "sha256-N4SSeEWmrvn5unw3XJRYS6eLMMINSeVhOuUrn/8GLhU="; # fill via nix-prefetch-url
  };

  format = "other";

  propagatedBuildInputs = with python3Packages; [
    typer
    rich
    pydantic
    pyyaml
    jinja2
    rapidfuzz
    httpx
    dnspython
    # add extras if you need them
  ];

  buildPhase = ''
    make
  '';

  # Install the CLI script
  installPhase = ''
    mkdir -p $out/bin
    # Copy the source to $out/share/ipcrawler
    cp -r . $out/share/ipcrawler
    # Create a wrapper to run it with Python
    cat > $out/bin/ipcrawler <<EOF
    #!${python3Packages.python.interpreter}
    import sys
    sys.path.insert(0, "$out/share/ipcrawler")
    from ipcrawler.cli import app
    if __name__ == "__main__":
        import typer
        typer.run(app)
    EOF
    chmod +x $out/bin/ipcrawler
  '';

  doCheck = false;

  meta = with lib; {
    description = "IPCrawler - intelligent wordlist recommendations and subnet crawler";
    homepage = "https://github.com/neur0map/ipcrawler";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = with lib.maintainers; [];
  };
}
