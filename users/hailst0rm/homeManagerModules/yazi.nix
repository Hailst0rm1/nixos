{
  pkgs-unstable,
  ...
}: {
  programs.yazi = {
    enable = true;
    package = pkgs-unstable.yazi;
    enableZshIntegration = true;

    settings = {
      manager = {
        ratio = [ 2 2 4 ];
        show_hidden = true;
      };
    };

    theme = {
      status = {
        separator_open = "█";
        separator_close = "█";
      };
    };
  };
}

