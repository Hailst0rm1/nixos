{ ... }: {
  imports = [
    ./bluetooth.nix
    ./bootloader.nix
    ./colemak-se_keyboard.nix
    ./fonts.nix
    ./networking.nix
    ./nix-settings.nix
    ./ssh.nix
    ./sshd.nix
    ./utils.nix
  ];
}
