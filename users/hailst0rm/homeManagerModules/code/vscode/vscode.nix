{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.code.vscode;
in {
  options.code.vscode.enable = lib.mkEnableOption "Enable VS Code";

  config = lib.mkIf cfg.enable {
    # VS Code setup
    programs.vscode = {
      enable = true;

      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          github.copilot
          continue.continue
          ms-vscode.live-server
          esbenp.prettier-vscode
          eamodio.gitlens
          wix.vscode-import-cost
          # Code runner?
          ms-vsliveshare.vsliveshare
          pkief.material-icon-theme
          mechatroner.rainbow-csv
        ];

        # Optional: Use VS Code Insiders instead of stable
        # package = pkgs.vscode-insiders;

        userSettings = {
          "editor.formatOnSave" = true;
          "editor.inlineSuggest.enabled" = true;
          "editor.codeActionsOnSave" = {
            "source.fixAll" = true;
            "editor.cursorSmoothCaretAnimation" = "on";
            "editor.wordWrap" = "on";
          };
        };
      };
    };
  };
}
