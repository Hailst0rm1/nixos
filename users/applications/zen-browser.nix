{zen-browser, pkgs, ...}: {
  home.packages = [
    zen-browser.packages.${pkgs.system}.default
  ];
}
