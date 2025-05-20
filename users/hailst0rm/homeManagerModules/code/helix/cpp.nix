{
  pkgs,
  config,
  lib,
  ...
}: {
  options.code.helix.languages.cpp = lib.mkEnableOption "Enable C++ in Helix";

  config = lib.mkIf config.code.helix.languages.cpp {
    programs.helix = {
      extraPackages = with pkgs; [
        clang-tools
      ];
    };
  };
}
