{ config, pkgs, lib, ... }:
let
  cfg = config.applications.vscode;
in {
  options.applications.vscode.enable = lib.mkEnableOption "Enable VS Code";

  config = lib.mkIf cfg.enable {
    programs.home-manager.enable = true;

    # Rust toolchain via rustup (more flexible than rustc/cargo from nixpkgs)
    home.packages = with pkgs; [
      rustup
      rust-analyzer
      cargo-watch
      clippy
      rustfmt
      # Optional tools
      git
      gh   # GitHub CLI for auth with Copilot CLI
    ];

    # VS Code setup
    programs.vscode = {
      enable = true;

      extensions = with pkgs.vscode-extensions; [
        rust-lang.rust-analyzer
        ms-vscode.cpptools
        ms-python.python
        # Optional: GitHub Copilot (note: needs Copilot access)
        github.copilot
      ];

      # Optional: Use VS Code Insiders instead of stable
      # package = pkgs.vscode-insiders;

      userSettings = {
        "rust-analyzer.cargo.allFeatures" = true;
        "rust-analyzer.checkOnSave.command" = "clippy";
        "editor.formatOnSave" = true;
        "editor.inlineSuggest.enabled" = true;
        "editor.codeActionsOnSave" = {
          "source.fixAll" = true;
        };
      };
    };

    # Optional: set up environment variables
    home.sessionVariables = {
      CARGO_HOME = "${config.home.homeDirectory}/.cargo";
      RUSTUP_HOME = "${config.home.homeDirectory}/.rustup";
    };
  };
}
