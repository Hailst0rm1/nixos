{
  config,
  lib,
  ...
}: {
  options.services = with lib; {
    domain = mkOption {
      type = types.str;
      default = "localhost";
      description = "Domain user for services, e.g. example.com";
    };
  };

  config = {
    # Makes sure to kill user processes on shutdown
    services.logind = {
      killUserProcesses = true;
    };
  };
}
