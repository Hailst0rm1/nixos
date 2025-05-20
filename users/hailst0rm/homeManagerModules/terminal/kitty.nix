{
  config,
  lib,
  ...
}: {
  config = lib.mkIf (config.terminal == "kitty") {
    programs.kitty = {
      enable = true;
      # keybindings = {
      #   "kitty_mod+h" = "neighboring_window left";
      #   "kitty_mod+l" = "neighboring_window right";
      #   "kitty_mod+j" = "neighboring_window down";
      #   "kitty_mod+k" = "neighboring_window up";
      # };
      #font.size = 14;
      shellIntegration.enableZshIntegration = true;
      settings = {
        enable_audio_bell = "no";

        window_padding_width = 5;
        #font_size = lib.mkDefault 16;

        # allow_remote_control = "yes";
        # listen_on = "unix:/tmp/kitty";
        shell_integration = "enabled";
      };
    };
  };
}
