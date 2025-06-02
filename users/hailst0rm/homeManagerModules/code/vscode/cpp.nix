{
  config,
  pkgs,
  lib,
  ...
}: {
  options.code.vscode.languages.cpp = lib.mkEnableOption "Enable C++ for VS Code";

  config = lib.mkIf config.code.vscode.languages.cpp {
    # VS Code setup
    programs.vscode = {
      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          ms-vscode.cpptools
        ];
      };
    };
  };
}
