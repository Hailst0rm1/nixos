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
  #   KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="01e1", MODE="0666", TAG+="uaccess", TAG+="udev-acl"

  #   # Generic rule for any Keychron device (in case the ID shifts in bootloader mode)
  #   SUBSYSTEMS=="usb", ATTRS{idVendor}=="3434", MODE="0666", TAG+="uaccess"

  #   KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="0b10", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
  # '';
}
