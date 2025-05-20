{...}: {
  programs.ssh = {
    startAgent = true;
    enableAskPassword = false;
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PubkeyAuthentication = true;
      PermitRootLogin = "no";
      LogLevel = "DEBUG";
    };
  };
}
