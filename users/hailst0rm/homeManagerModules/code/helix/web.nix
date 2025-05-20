{
  pkgs,
  config,
  lib,
  ...
}: {
  options.code.helix.languages.web = lib.mkEnableOption "Enable Web-languages in Helix";

  config = lib.mkIf config.code.helix.languages.web {
    programs.helix = {
      extraPackages = with pkgs; [
        stylelint # CSS
        stylelint-lsp
        nodePackages.typescript-language-server # Typescript
      ];
    };
  };
}
