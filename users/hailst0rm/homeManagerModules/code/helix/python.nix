{
  pkgs,
  config,
  lib,
  ...
}: {
  options.code.helix.languages.python = lib.mkEnableOption "Enable Python in Helix";

  config = lib.mkIf config.code.helix.languages.python {
    programs.helix = {
      extraPackages = with pkgs; [
        yapf
        zathura
        (python313.withPackages (
          p:
            with p;
              [
                psutil
                python-lsp-server
              ]
              ++ python-lsp-server.optional-dependencies.all
        ))
        pyright
      ];
    };
  };
}
