{ pkgs, config, lib, ... }: {
  options.code.helix.languages.rust = lib.mkEnableOption "Enable Rust in Helix";

  config = lib.mkIf config.code.helix.languages.rust {
    programs.helix = {
      languages = {
        language-server = {
          rust-analyzer = {
            config.rust-analyzer = {
              cargo.loadOutDirsFromCheck = true;
              checkOnSave.command = "clippy";
              procMacro.enable = true;
              lens = {
                references = true;
                methodReferences = true;
              };
              completion.autoimport.enable = true;
              experimental.procAttrMacros = true;
            };
          };
        };

        language = [
          {
            name = "rust";
            auto-format = false;
            file-types = [
              "lalrpop"
              "rs"
            ];
            language-servers = [ "rust-analyzer" ];
          }
        ];
      };

      extraPackages = with pkgs; [
        rust-analyzer
      ];
    };
  };
}
