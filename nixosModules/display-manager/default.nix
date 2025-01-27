{
  pkgs,
  username,
  desktop,
  ...
}:
# Enable Display Manager
#services.displayManager.sddm = {
# enable = true;
# };
let
  tuigreet = "${pkgs.greetd.tuigreet}/bin/tuigreet";
in {
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${desktop}";
        user = "${username}";
      };
      default_session = {
        command = "${tuigreet} --greeting 'Welcome to NixOS!' --asterisks --remember --remember-user-session --time --cmd ${desktop}";
        user = "greeter";
      };
    };
  };
}

