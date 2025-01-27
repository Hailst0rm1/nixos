{pkgs-unstable, ...}: {
  services.ollama = {
    enable = false;
    acceleration = "cuda";
    package = pkgs-unstable.ollama;
  };
}

