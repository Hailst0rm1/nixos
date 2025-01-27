{...}: {
  programs.ssh = {
    startAgent = true;
    enableAskPassword = false;
  };
}

