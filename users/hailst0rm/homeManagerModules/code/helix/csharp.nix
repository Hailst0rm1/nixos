{ pkgs, config, lib, ... }: {
  options.code.helix.languages.cSharp = lib.mkEnableOption "Enable C# in Helix";

  config = lib.mkIf config.code.helix.languages.cSharp {
    programs.helix = {

      extraPackages = with pkgs; [
        omnisharp-roslyn # .NET
        netcoredbg
      ];
      # languages.language = [
      #   {
      #     name = "csharp";
      #     language-servers = [ "omnisharp" ];
      #   }
      # ];
    };
  };
}
