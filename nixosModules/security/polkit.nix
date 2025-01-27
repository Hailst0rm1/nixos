{...}: {
  security.polkit = {
    enable = true;
  };
  programs.gnupg.agent.enable = true;
}

