{
  config,
  lib,
  inputs,
  ...
}: {
  imports = [inputs.nixcord.homeModules.nixcord];

  config = lib.mkIf config.applications.discord.enable {
    programs.nixcord = {
      enable = true; # enable Nixcord. Also installs discord package
      #quickCss = "some CSS";  # quickCSS file
      config = {
        #useQuickCss = true;   # use out quickCSS
        themeLinks = [
          # or use an online theme
          "https://raw.githubusercontent.com/catppuccin/discord/refs/heads/main/themes/mocha.theme.css"
        ];
        #frameless = true; # set some Vencord options
        plugins = {
          fakeNitro.enable = true;
          #hideAttachments.enable = true;    # Enable a Vencord plugin
          #ignoreActivities = {    # Enable a plugin and set some options
          #enable = true;
          #ignorePlaying = true;
          #ignoreWatching = true;
          #ignoredActivities = [ "someActivity" ];
          #};
        };
      };
      #extraConfig = {
      # Some extra JSON config here
      # ...
      #};
    };
  };
}
