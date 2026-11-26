{lib, ...}: {
  imports = [./default.nix];

  # Override only what's different from default
  importConfig.hyprland = {
    accentColour = "peach";
    monitorOrientations = {
      "DP-1" = "center";
      "DP-2" = "top";
      "DP-3" = "top";
    };
  };

  code.claude-code.enable = true;
  code.codex.enable = true;
  importConfig.zsh-history-sync.enable = true;

  applications = {
    youtube-music.enable = true;
    openconnect.enable = false;
    aws-cvpn-wrapper.enable = false;
  };

  # This host's network blocks outbound port 22, so reach GitHub's SSH
  # endpoint over 443 (ssh.github.com serves the same host keys). Merges
  # with the github.com block in homeManagerModules/terminal/ssh.nix.
  programs.ssh.settings."github.com" = {
    HostName = "ssh.github.com";
    Port = 443;
  };
  # Same for the Dfirmed account; mkForce beats the github.com HostName
  # the ssh.nix alias sets.
  programs.ssh.settings."github-dfirmed" = {
    HostName = lib.mkForce "ssh.github.com";
    Port = 443;
  };
}
