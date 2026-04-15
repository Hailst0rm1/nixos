{
  config,
  pkgs,
  lib,
  ...
}: {
  options.code.terraform.enable = lib.mkEnableOption "Enable Terraform tooling";

  config = lib.mkIf config.code.terraform.enable {
    home.packages = with pkgs; [
      terraform
      terraform-ls
      awscli2
    ];

    # VS Code setup
    programs.vscode = {
      profiles.default = {
        extensions = with pkgs.vscode-marketplace; [
          _4ops.terraform
        ];
      };
    };
  };
}
