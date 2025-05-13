{ config, pkgs, lib, ... }:
let
  cfg = config.code.vscode;
in {
  options.code.vscode.enable = lib.mkEnableOption "Enable VS Code";

  config = lib.mkIf cfg.enable {

    # VS Code setup
    programs.vscode = {
      enable = true;

      extensions = with pkgs.vscode-extensions; [
        github.copilot
      ];

      # Optional: Use VS Code Insiders instead of stable
      # package = pkgs.vscode-insiders;

      userSettings = {
        "editor.formatOnSave" = true;
        "editor.inlineSuggest.enabled" = true;
        "editor.codeActionsOnSave" = {
          "source.fixAll" = true;
        };
      };
    };
  };
}
