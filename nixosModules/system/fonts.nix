{pkgs, ...}: {
  # Fonts
  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-font-patcher
    noto-fonts-color-emoji
    rubik
    noto-fonts
    noto-fonts-emoji
  ];
}
