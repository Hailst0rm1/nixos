{
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: {
  home.packages = [
    # pkgs.vagrant
    pkgs.kitty
    pkgs.mysql84
    pkgs.mycli
    pkgs.jdk25 # D0019N: JDK 25 LTS, java/javac on PATH
  ];

  # D0019N: VS Code as the IDE; "Extension Pack for Java" per the course page
  programs.vscode.profiles.default.extensions = [pkgs.vscode-marketplace.vscjava.vscode-java-pack];
}
