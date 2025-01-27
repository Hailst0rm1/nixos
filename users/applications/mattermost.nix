{pkgs, ...}: {
  home.packages = [
    pkgs.mattermost
  ];

  services.mattermost = {
    enable = true;
    siteUrl = "https://localhost:8065";
  };
}

