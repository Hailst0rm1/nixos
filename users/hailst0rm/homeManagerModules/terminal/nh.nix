{
  config,
  pkgs-unstable,
  ...
}: {
  # nh - Yet another Nix CLI helper
  # https://github.com/nix-community/nh

  programs = {
    nh = {
      enable = true;
      package = pkgs-unstable.nh;
      flake = "${config.nixosDir}";
      clean = {
        enable = true;
        extraArgs = "--keep 5 --keep-since 3d";
      };
    };
    zsh.envExtra = ''
      export NH_FLAKE="${config.nixosDir}"
    '';
  };
}
