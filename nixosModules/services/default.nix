{config, ...}: {
  # Makes sure to kill user processes on shutdown
  services.logind = {
    killUserProcesses = true;
  };
}
