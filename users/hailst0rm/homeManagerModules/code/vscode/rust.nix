{ config, pkgs, lib, ... }: {
  options.code.vscode.languages.rust = lib.mkEnableOption "Enable Rust for VS Code";

  config = lib.mkIf config.code.vscode.languages.rust {
    # Rust toolchain via rustup (more flexible than rustc/cargo from nixpkgs)
    home.packages = with pkgs; [
      rustup
      cargo-watch
      rust-analyzer
    ];

    # VS Code setup
    programs.vscode = {
      extensions = with pkgs.vscode-extensions; [
        rust-lang.rust-analyzer
      ];
      userSettings = {
        "rust-analyzer.cargo.allFeatures" = true;
        "rust-analyzer.checkOnSave.command" = "clippy";
      };
    };
    
    # Optional: set up environment variables
    home.sessionVariables = {
      CARGO_HOME = "${config.home.homeDirectory}/.cargo";
      RUSTUP_HOME = "${config.home.homeDirectory}/.rustup";
    };
  };
}
