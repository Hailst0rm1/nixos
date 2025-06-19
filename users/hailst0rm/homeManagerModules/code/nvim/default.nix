{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: {
  imports = [inputs.nvf.homeManagerModules.default];

  options.code.neovim.enable = lib.mkEnableOption "Enable Neovim";

  config = lib.mkIf (config.editor == "nvim" || config.editor == "neovim" || config.code.neovim.enable) {
    programs.nvf = {
      enable = true;
      settings = {
        vim = {
          viAlias = true;
          vimAlias = true;
          clipboard.enable = true;
          searchCase = "smart";

          preventJunkFiles = true;

          undoFile = {
            enable = true;
          };

          theme = {
            enable = true;
            name = "catppuccin";
            style = "mocha";
          };

          mini.tabline.enable = true;
          statusline.lualine.enable = true; # Status bar
          telescope.enable = true; # Fuzzy finder
          autocomplete.nvim-cmp.enable = true; # Autocomplete

          options = {
            cursorlineopt = "both";
            shiftwidth = 4;
            tabstop = 4;
            softtabstop = 4;
          };

          # Language servers
          lsp.enable = true;
          languages = {
            enableTreesitter = true;

            nix.enable = true;
            rust.enable = true;
          };
          vim.keymaps = [
            #{
            #key = "<leader>m";
            #mode = "n";
            #silent = true;
            #action = ":make<CR>";
            #}
            #{
            #key = "<leader>l";
            #mode = ["n" "x"];
            #silent = true;
            #action = "<cmd>cnext<CR>";
            #}
          ];
        };
      };
    };
  };
}
