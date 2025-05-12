{ config, lib, ... }: 
let
  cfg = config.services.openWebui;
in {
  services.open-webui.enable = lib.mkIf cfg.enable {
    # environment = {
    #   OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
    #   # Disable authentication
    #   WEBUI_AUTH = "False";
    #   ANONYMIZED_TELEMETRY = "False";
    #   DO_NOT_TRACK = "True";
    #   SCARF_NO_ANALYTICS = "True";
    # };
  };
}
