{ config, lib, ... }: 
let
  cfg = config.services.open-webui;
in {
  services.open-webui = lib.mkIf cfg.enable {
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
