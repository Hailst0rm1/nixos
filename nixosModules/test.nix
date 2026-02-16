{
  pkgs,
  pkgs-unstable,
  lib,
  config,
  ...
}: {
  environment.systemPackages = [
  ];
  # services.udev.extraRules = ''
  #   # Rule for Keychron Q11 (Standard and Split communication)
  #   KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="01e1", MODE="0666", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
  # '';
}
