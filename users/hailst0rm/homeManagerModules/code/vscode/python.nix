{ config, pkgs, lib, ... }: {
  options.code.vscode.languages.python = lib.mkEnableOption "Enable Python for VS Code";

  config = lib.mkIf config.code.vscode.languages.python {

    # VS Code setup
    programs.vscode = {
      extensions = with pkgs.vscode-extensions; [
        ms-python.python
      ];
    };
  };
}
